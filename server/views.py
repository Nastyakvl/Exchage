# views.py
from aiohttp import web

async def index(request):
	 return web.json_response({'some': 'data', 'key': 'hello'})


async def variable_handler(request):
    return web.Response(
        text="Hello, {}".format(request.match_info['name']))
