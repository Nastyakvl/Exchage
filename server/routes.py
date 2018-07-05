# routes.py
from views import index
from views import variable_handler

def setup_routes(app):
    app.router.add_get('/', index),
    app.router.add_get('/{name}', variable_handler)


