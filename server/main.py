# main.py
import asyncio
from aiohttp import web
import json
import random


random.seed() 

List=list(range(1,500+1,1))
	
access = {str(a): list(map(str,List)) for a in list(range(501,1001+1,1))}


#access={'101': ['204', '109', '567', '01', '45'],
#	'102': ['607', '339', '777', '02', '55'],
#	'103': ['607', '339', '777', '02', '205'],
#	'104': ['1', '2', '777', '02', '205'],
#	'12': ['2', '3', '777', '02', '205'],
#	'13': ['4', '339', '777', '02', '205'],
#	'14': ['4', '5', '777', '02', '205'],
#	'15': ['6', '339', '777', '02', '205']}


async def isAllowed(request):
	id=str(request.match_info['id1'])
	return web.json_response({'accessTo': access.get(id)}) #возвращает id генераторов, к сообщениям которых имеет доступ данный пользователь

#def startapp(args):
#	app = web.Application()
#	app.add_routes([web.get('/idCons={id1}', isAllowed)])
#	return app

app = web.Application()
app.router.add_route('GET','/idCons={id1}', isAllowed)
loop = asyncio.get_event_loop()
handler = app.make_handler()
f = loop.create_server(handler, 'localhost', 8080)
srv = loop.run_until_complete(f)
print('serving on', srv.sockets[0].getsockname())
try:
    loop.run_forever()
except KeyboardInterrupt:
    pass
finally:
    loop.run_until_complete(handler.finish_connections(1.0))
    srv.close()
    loop.run_until_complete(srv.wait_closed())
    loop.run_until_complete(app.finish())
loop.close()
