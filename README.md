# Tips de ingenieros

Referencia en español sobre ingeniería de software: estilos de arquitectura, principios de diseño y prácticas de trabajo con Git. Cada página explica una idea con palabras propias, dice cuándo **no** conviene usarla y cita las fuentes originales para que puedas comprobar lo que afirma.

> **Estado:** en construcción. Las páginas se agregan de a una, por pull request revisado.

## Para quién es

Para desarrolladores que ya programan y quieren entender por qué se recomiendan ciertas prácticas, no solo cómo aplicarlas. Los ejemplos de código usan Java 21 con Spring Boot 3.x y, cuando aporta, C# con .NET 8.

## Índice

| Carpeta | Contenido | Estado |
| --- | --- | --- |
| `arquitectura/` | Capas, hexagonal, clean architecture, microservicios | Pendiente |
| `principios/` | SOLID; DRY, KISS y YAGNI; patrones de diseño | Pendiente |
| `git/` | Conventional Commits, estrategias de ramas, code review | Pendiente |
| `pruebas/` | Pirámide y trofeo, dobles de prueba, TDD | Pendiente |
| `datos/` | Transacciones y aislamiento, concurrencia optimista y pesimista, ORM y N+1 | Pendiente |
| `apis/` | REST y modelo de Richardson, idempotencia, paginación | Pendiente |

## Cómo leer cada página

Todas las páginas siguen la misma estructura: el problema que resuelve la idea, la idea central, su estructura, cuándo no usarla, qué se gana y qué se pierde, confusiones frecuentes, un ejemplo y las referencias. Las páginas de arquitectura comparten un mismo dominio de ejemplo (un sistema de pedidos) para que puedas compararlas.

## Encontraste un error

Abre un issue con el formulario **Error de contenido** e indica la fuente que muestra el error. Las correcciones con fuente se priorizan.

## Contribuir

Lee [CONTRIBUTING.md](CONTRIBUTING.md). Ningún cambio entra a `main` sin un pull request aprobado por otra persona.

## Cómo citar

> Joako601 y Josspoot. *Tips de ingenieros*. GitHub, 2026. Licencia CC BY 4.0.

Indica la página concreta y, si puedes, el commit que consultaste.

## Licencia

- El texto y los diagramas están bajo [CC BY 4.0](LICENSE): puedes reutilizarlos y adaptarlos citando la fuente.
- Los fragmentos de código están bajo [MIT](LICENSE-CODE), para que puedas copiarlos en tus proyectos sin las condiciones de una licencia pensada para texto.

## Autores

- [@Joako601](https://github.com/Joako601)
- [@Josspoot](https://github.com/Josspoot)
