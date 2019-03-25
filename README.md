# rabbit_auth_exchange

Implementation of a new type of exchange for routing messages based on user security policies in the RabbitMQ system.

Routing key should be set as follow: "id.group.class.kind"
 - id - identificator of generator
 - group.class.kind - topic of message
 
When binding queue with the exchange point, it is necessary  to send client id in arguments. Clienr Id should be a string. 
Example on Python:
```python 
channel.queue_bind(exchange='testAuth',
                       queue='con2',
                       routing_key='89.*.orange', 
		        arguments=dict(id='109'))
```

where:
* 'testAuth' - name of eachange point
* 'con2' - name of client queue
* '89.*.orange' - routing key
* '109' - client id


## Instalation 
                                               
Download file .ez
[GitHub releases](https://github.com/Nastyakvl/Exchage/releases) 

Copying file `*.ez` in [RabbitMQ plugins directory](http://www.rabbitmq.com/relocate.html).

Install the plugin for RabbitMQ:
[sudo] rabbitmq-plugins enable rabbitmq_auth_exchange

Restart the RabbitMQ server.

For using this exchange point now just use type of exchange point as "x-auth".


## Installation from source

Require dependencies:

1. Python 2 or next versions 
2. Erlang 
3. Elixir
4. GNU make
5. xsltproc (part of libxslt)
6. xmlto
7. zip or unzip

Execute the following command:

    git clone https://github.com/Nastyakvl/rabbit_auth_exchange.git
    cd rabbit_auth_exchange
    make
    make dist

Copying file `*.ez` from folder `plugins` to [RabbitMQ plugins directory](http://www.rabbitmq.com/relocate.html).
Enable plugin:

    [sudo] rabbitmq-plugins enable rabbitmq_auth_exchange

Also see: [RabbitMQ Plugin Development guide](http://www.rabbitmq.com/plugin-development.html).


## Example


###python.


Generator:

```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-
import pika
import sys

connection = pika.BlockingConnection(pika.ConnectionParameters(host='localhost'))
channel = connection.channel()

#create exchange point
channel.exchange_declare(exchange='testAuth',
                         exchange_type='x-auth')

severity = sys.argv[1] if len(sys.argv) > 2 else 'info'
message = ' '.join(sys.argv[2:]) 
#publishing a msg
channel.basic_publish(exchange='testAuth',
                      routing_key='89.circle.orange',
                      body=message)
print(" [x] Sent %r:%r" % (severity, message))
connection.close()
```

Client
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-
import pika
import sys

connection = pika.BlockingConnection(pika.ConnectionParameters(host='localhost'))
channel = connection.channel()

channel.exchange_declare(exchange='testAuth',
                         exchange_type='x-auth')
# declare a queue
channel.queue_declare(queue='con1',exclusive=True)

# binding the queue.  arguments=dict(id='205') - client id
channel.queue_bind(exchange='testAuth',
                       queue='con1',
                       routing_key='89.*.orange', 
		        arguments=dict(id='205'))

# binding the queue with the other key
channel.queue_bind(exchange='testAuth',
                       queue='con1',
                       routing_key='79.*.green' ,
		        arguments=dict(id='205'))

# binding the queue with the other key
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

Send msg by generator:
``` 
python sender sent Hello World
```

We expect to get msg with key '89.*.orange':
```
nastya@nastya-VirtualBox:~/Downloads$ python con
 [*] Waiting for logs. To exit press CTRL+C
 [x] '89.circle.orange':'Hello World'
```

