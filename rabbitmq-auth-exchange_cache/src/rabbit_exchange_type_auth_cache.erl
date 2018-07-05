%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is VMware, Inc.
%% Copyright (c) 2007-2011 VMware, Inc.  All rights reserved.
%%

-module(rabbit_exchange_type_auth_cache).
-behaviour(rabbit_exchange_type).
-include_lib("rabbit_common/include/rabbit.hrl").
-compile([{parse_transform, lager_transform}]).


%% Регистрация точки обмена
-rabbit_boot_step({?MODULE, [
  {description,   "exchange type authentification plus cache"},
  {mfa,           {rabbit_registry, register, [exchange, <<"x-auth-cache">>, ?MODULE]}},
  {requires,      rabbit_registry},
  {enables,       kernel_ready}
]}).


-rabbit_boot_step({rabbit_exchange_type_auth_ets,
                  [{description, "exchange type authentification:ets"},
                  {mfa, {?MODULE, setup_schema, []}}
		]}).
-define(ETS_TABLE,cache).



-export([setup_schema/0]).
-export([
  add_binding/3, 
  assert_args_equivalence/2,
  create/2, 
  delete/3, 
  policy_changed/2,
  description/0, 
 
  remove_bindings/3,
  validate_binding/2,
  route/2,
  serialise_events/0,
  validate/1,
  info/1,
  info/2
]).




description() ->
    [{name, <<"x-auth-cache">>}, {description, <<"Authentification for consumers with cache">>}].


route(X,D=#delivery{message = #basic_message{routing_keys = Routes}}) ->
	
	inets:start(),
	lager:start(),
	%lager:warning("start "),
 	List=rabbit_exchange_type_topic:route(X,D), %% Возвращает список очередей, удовлетворяющих логике поведения точки обмена типа "topic"  
	IdPubl = hd( binary:split(hd(Routes),<<".">>,[])), %% идентификатор генератора
	% lager:warning("idPubl ~p", [IdPubl]),
	%lager:warning("idPubl ~p", [List]),
	NewQueues=allowedQueue(X#exchange.name,IdPubl,List,[]), 
	NewQueues.

%% Возвращает новый список очередей. В списке находятся только те очереди, пользователь которых имеет доступ к текущему сообщению
allowedQueue(_ExName,_,[],NewList) -> NewList; 
									  
allowedQueue(ExName,IdPubl,[CurrentQueue|Tail],NewList)->
	%% запрос к БД Mnesia RabbitMQ. В таблице rabbit_route содержится вся информация о связях. 
	%% Возвращает аргументы связи очереди с точкой обмена
	MatchHead = #route{binding = #binding{source      = ExName,
                                             destination = CurrentQueue,
					      args='$1',
                                               _           = '_'}},
        Args=ets:select(rabbit_route, [{MatchHead, [], ['$1']}]),
	lager:warning("Args ~p", [Args]),
	{_,_,IdCons} = hd(hd(Args)), %%идентификатор подписчика
	 lager:warning("idCons ~p", [IdCons]),
	lager:warning("idPubl ~p", [IdPubl]),
	%% Ответ true-имеет доступ  или false - не имеет.
	Allowed = isAllowed(IdPubl,IdCons),
	case Allowed of
	true -> allowedQueue(ExName,IdPubl,Tail,[CurrentQueue|NewList]);
	false -> allowedQueue(ExName,IdPubl,Tail,NewList)
	end.


%% Функция, определяющая имеет ли доступ конкретный подписчик к данному сообщению
isAllowed(_IdPubl,_IdCons) ->
 %lager:warning("inISAllowed ~p", []),

  InCache = ets:lookup(?ETS_TABLE,_IdCons),
  case InCache of
  [] ->  AccessAllowed = requestServer(_IdCons),
	%{ok,{_,_,Ans}} = httpc:request("http://bg502.ru:80/idCons="++binary_to_list(_IdCons)),
 	%lager:warning("SEE HERE ~p", [Ans]),
	%lager:warning("decode ~p", [rabbit_json:decode(list_to_binary(Ans))]),
	%#{<<"accessTo">> := AccessAllowed}=rabbit_json:decode(list_to_binary(Ans)),
	%lager:warning("AccessAllowed ~p", [_IdCons,AccessAllowed]),
	%lager:warning("AccessAllowed& ~p", [lists:member(_IdPubl, AccessAllowed)]),
	%lager:warning("LOOKUP ~p", [ets:lookup(?ETS_TABLE,_IdCons)]),
	insert(_IdCons, AccessAllowed),
	lists:member(_IdPubl, AccessAllowed);
  [{_,LastTime, X}] ->  lager:warning("CACHE ~p", [InCache]),
			{MegaSecs, Secs, Microsecs} = erlang:timestamp(),
			CurrentTime = (MegaSecs * 1000000) + Secs + (Microsecs / 1000000),
			%lager:warning("TIME ~p", [CurrentTime-LastTime]),
			if
			   CurrentTime-LastTime > 300000 ->  AccessAllowed = requestServer(_IdCons), 
							     insert(_IdCons, AccessAllowed),
							     lists:member(_IdPubl, AccessAllowed);
			   true -> lists:member(_IdPubl, X)
			end
  end.

insert(_IdCons, AccessAllowed) ->
	{MegaSecs, Secs, Microsecs} = erlang:timestamp(),
	Time = (MegaSecs * 1000000) + Secs + (Microsecs / 1000000),
	lager:warning("INSERT~p", []),
	ets:insert(?ETS_TABLE, {_IdCons, Time, AccessAllowed}).

requestServer(_IdCons)-> 
	lager:warning("BEFORE_REQUEST~p", []),
	{ok,{_,_,Ans}} = httpc:request("http://bg502.ru:80/idCons="++binary_to_list(_IdCons)),
	lager:warning("REQUEST~p", []),
 	#{<<"accessTo">> := AccessAllowed}=rabbit_json:decode(list_to_binary(Ans)),
	lager:warning("SEE HERE ~p", [Ans]),
	AccessAllowed.




info(_X) -> [].
info(_X, _) -> [].
serialise_events() -> false.
validate(_X) -> ok.
create(_Tx, _X) -> ok.


delete(_Tx, _X, _Bs) -> rabbit_exchange_type_topic:delete(_Tx, _X, _Bs),
			ets:delete(?ETS_TABLE).

policy_changed(_X1, _X2) -> ok.




add_binding(_Tx, _X, _B) -> rabbit_exchange_type_topic:add_binding(_Tx, _X, _B).



remove_bindings(_Tx, _X, _Bs) -> rabbit_exchange_type_topic:remove_bindings(_Tx, _X, _Bs).

validate_binding(_X, _B) -> ok.
assert_args_equivalence(X, Args) ->
    rabbit_exchange:assert_args_equivalence(X, Args).

setup_schema() ->
	ets:new(?ETS_TABLE,[named_table,public]),
	ok.
