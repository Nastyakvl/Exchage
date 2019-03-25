# rabbit_auth_exchange

Данная точка обмена (exchange) выполняет маршрутизацию по заданной теме с выполнением авторизации пользователей.

На данный момент r.k. сообщений (событий, которые создаются генераторами) должны задаваться как "id.group.class.kind", где id - идентификатор генератора.
При связывании очереди подписчика с данной точкой обмена, необходимо указать идентификатор подписчика в аргументах. Id пользователя должен быть задан строкой. Пример привязки очереди для клиента на языке python:
```python 
channel.queue_bind(exchange='testAuth',
                       queue='con2',
                       routing_key='89.*.orange', 
		        arguments=dict(id='109'))
```

где:
* 'testAuth' - название точки обмена
* 'con2' - название очереди данного клиента
* '89.*.orange' - ключ маршрутизации (кouting key)
* '109' - идентификатор пользователя (id) 


Расширения для RabbitMQ должны реализовывать одно из определенных в RabbitMQ поведений (behaviour) на языке Erlang. В данном случае должно реализовываться поведение rabbit_exchange_type. 

Основная функция - route, которая вызывается при маршрутизации каждого сообщения. В данном случае, в этой функции вызывается функция route точки обмена topic, которая возвращает список очередей, которые удовлетворяют ключу маршрутизации сообщения. После чего, вызывается функция allowedQueue, в которую передается название точки обмена, идентификатор генератора, опубликовавщий данное сообщение и список очередей, полученный ранее. Функция allowedQueue возвращает новый список, состоящий только из тех очередей, пользователи которых имеют права доступа к данному сообщению.

В методе allowedQueue происходит обращение к серверу. Серверу отправляется id запрашиваемого пользователя. В ответ отправяется список всех пользователей, доступ к которым имеет пользователь с переданным id. Ответ возвращается в формате JSON.  
Принцип работы точки обмена:
1. Получаем список всех очередей, пользователи которых заинтересованы в данном сообщении: rabbit_exchange_type_topic:route(X,D)
2. Сокращаем список только до тех очередей, пользователи которых имеют права досутпа для получения соощбений от генератора, опубликовавшего данное сообщение: allowedQueue
3. В методе isAllowed запрашиваем права доступа для idCons, idCons - идентификатор пользователя, очередь которого проверяется в текущий момент времени. 

	

## Установка
                                               
Для установки данного расширения необходимо скачать файл с расширением .ez
[GitHub releases](https://github.com/Nastyakvl/Exchage/releases) 

Cкопировать файл `*.ez` в [RabbitMQ plugins directory](http://www.rabbitmq.com/relocate.html).

Затем, установить расширение для сервера RabittMQ, для чего выполнить команду:
[sudo] rabbitmq-plugins enable rabbitmq_auth_exchange

Возможно, понадобиться перезапустить сервер.

Для использования расширения достаточно при создании точки обмена указать тип: "x-auth".


## Сборка из исходного текста

Для сборки проекта, необходимо установить все зависимости:

1. Python 2 или более новая версия 
2. Erlang 
3. последняя версия Elixir
4. последняя версия GNU make
5. последняя версия xsltproc, которая является частью libxslt
6. последняя версия xmlto
7. zip или unzip

Для того, чтобы собрать расширение выполнить следующие команды:

    git clone https://github.com/Nastyakvl/rabbit_auth_exchange.git
    cd rabbit_auth_exchange
    make
    make dist

Cкопировать все файлы `*.ez` из папки `plugins` в [RabbitMQ plugins directory](http://www.rabbitmq.com/relocate.html).
И установить расширение:

    [sudo] rabbitmq-plugins enable rabbitmq_auth_exchange

Процесс сборки расширений также объясняется в: [RabbitMQ Plugin Development guide](http://www.rabbitmq.com/plugin-development.html).


## Пример использования


Пример будет представлен на языке python.


Генетатор:

```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-
import pika
import sys

connection = pika.BlockingConnection(pika.ConnectionParameters(host='localhost'))
channel = connection.channel()

#создание точки обмена
channel.exchange_declare(exchange='testAuth',
                         exchange_type='x-auth')

severity = sys.argv[1] if len(sys.argv) > 2 else 'info'
message = ' '.join(sys.argv[2:]) 
#публикация сообщения
channel.basic_publish(exchange='testAuth',
                      routing_key='89.circle.orange',
                      body=message)
print(" [x] Sent %r:%r" % (severity, message))
connection.close()
```

Подписчик
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-
import pika
import sys

connection = pika.BlockingConnection(pika.ConnectionParameters(host='localhost'))
channel = connection.channel()

channel.exchange_declare(exchange='testAuth',
                         exchange_type='x-auth')
# объявление очереди
channel.queue_declare(queue='con1',exclusive=True)

# привязка очереди.  arguments=dict(id='205') - задает идентификатор подписчика
channel.queue_bind(exchange='testAuth',
                       queue='con1',
                       routing_key='89.*.orange', 
		        arguments=dict(id='205'))

# привязка очереди с другим ключем
channel.queue_bind(exchange='testAuth',
                       queue='con1',
                       routing_key='79.*.green' ,
		        arguments=dict(id='205'))

# привязка очереди с другим ключем
channel.queue_bind(exchange='testAuth',
                       queue='con1',
                       routing_key='109.*.orange' ,
		        arguments=dict(id='205'))

print(' [*] Waiting for logs. To exit press CTRL+C')

def callback(ch, method, properties, body):
    print(" [x] %r:%r" % (method.routing_key, body))

channel.basic_consume(callback,
                      queue='con1',
                      no_ack=True)

channel.start_consuming()
```

Отправка сообщения генератором:
``` 
python sender sent Hello World
```

В данном примере ожидается, что пользователь получит сообщение по ключу маршрутизации '89.*.orange':
```
nastya@nastya-VirtualBox:~/Downloads$ python con
 [*] Waiting for logs. To exit press CTRL+C
 [x] '89.circle.orange':'Hello World'
```

