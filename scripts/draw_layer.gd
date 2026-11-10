extends Node2D
## Camada de desenho generica: delega o _draw para um Callable.
## Usada para o mundo (abaixo da escuridao) e para a mascara de luz.

var painter: Callable

func _draw() -> void:
    if painter.is_valid():
        painter.call(self)
