# REST y el modelo de madurez de Richardson

<!-- cspell:words Fielding Richardson HATEOAS RPC Nottingham Wilde Dalal ProblemDetail hipermedia accion idempotentes idempotente tipado Modelarlas cancelacion ubicacion Reschke -->

> **Tipo de página:** explicación. Te ayuda a entender qué es REST, qué no es y qué parte de sus ideas conviene aplicar en una API; no es una guía de diseño de URLs.

## El problema

Se llama "API REST" a casi cualquier servicio que intercambia JSON por HTTP. Muchas de esas APIs usan `POST /obtenerPedidos` para leer, o responden `200 OK` con `{"error": true}` en el cuerpo cuando algo falla.

Funcionan, pero pierden lo que HTTP ofrece gratis:

- Los intermediarios no pueden guardar en caché las lecturas si todas son `POST`.
- Un cliente no puede saber si es seguro repetir una petición que se cortó.
- Las herramientas de monitoreo ven `200` en todas las respuestas y no detectan los errores.

## La idea central

**REST** (*Representational State Transfer*) es un estilo de arquitectura que Roy Fielding definió en el capítulo 5 de su tesis doctoral, en 2000. Lo describe como un conjunto de restricciones: cliente-servidor, sin estado, con caché, con interfaz uniforme, en capas y, de forma opcional, con código bajo demanda.

La **interfaz uniforme** es la restricción central. Fielding la define con cuatro restricciones: los recursos se identifican con URIs, se manipulan a través de sus representaciones, los mensajes se describen a sí mismos y la aplicación avanza siguiendo enlaces que el servidor entrega en sus respuestas. Esta última parte se conoce como hipermedia, o HATEOAS (*Hypermedia As The Engine Of Application State*).

En 2008 Fielding escribió que, si la API no está guiada por hipertexto, no es REST, y que una API que no cumple esa restricción no debería llamarse REST.

**El modelo de madurez de Richardson**, que Leonard Richardson presentó y Martin Fowler difundió en 2010, ordena las ideas de REST en pasos:

| Nivel | Qué agrega | Ejemplo con pedidos |
| --- | --- | --- |
| 0 | HTTP como transporte de llamadas remotas, con un solo punto de entrada | `POST /api` con `{"accion": "crearPedido", ...}` |
| 1 | Recursos: cada cosa tiene su URI | `POST /pedidos/123/cancelar` |
| 2 | Métodos HTTP según su significado y códigos de estado | `GET /pedidos/123`, `POST /pedidos` que responde `201 Created` |
| 3 | Controles de hipermedia: la respuesta incluye los enlaces a las acciones posibles | El pedido trae un enlace a `cancelar` solo si todavía se puede cancelar |

## Cómo se estructura

En el **nivel 2**, cada método HTTP se usa con el significado que le da la especificación, el RFC 9110:

- **`GET` es seguro:** no pide cambios en el servidor. Fowler destaca la consecuencia: cualquier participante del camino puede guardar la respuesta en caché.
- **`PUT` y `DELETE` son idempotentes:** repetirlos tiene el mismo efecto que hacerlos una vez.
- **`POST` no es seguro ni idempotente:** se usa para crear o para operaciones que no encajan en los otros métodos.
- **Los códigos de estado dicen qué pasó.** `201 Created` indica que se creó un recurso, y la cabecera `Location` dice dónde está. `409 Conflict` indica un conflicto con el estado actual del recurso.

Para los errores, el **RFC 9457** (*Problem Details for HTTP APIs*, 2023) define un formato estándar en JSON, con el tipo de contenido `application/problem+json` y campos como `type`, `title`, `status` y `detail`. Reemplaza al RFC 7807. Spring Boot 3 lo soporta con la clase `ProblemDetail`.

## Cuándo no usarlo

- **Para llamadas internas entre servicios con contrato estricto y alto volumen.** Un protocolo de llamadas remotas tipado, como gRPC, puede encajar mejor que recursos y representaciones.
- **El nivel 3 cuando ningún cliente va a seguir los enlaces.** La hipermedia rinde cuando los clientes descubren las acciones posibles en tiempo de ejecución. Si todos los clientes tienen las URLs escritas en el código, los enlaces agregan bytes y trabajo sin beneficio.
- **Forzar todo en recursos y métodos.** Algunas operaciones son acciones de negocio, como cancelar un pedido. Modelarlas como `POST /pedidos/123/cancelacion` es razonable, aunque no sea un recurso "puro".

## Qué se gana y qué se pierde

| Nivel | Se gana | Se pierde |
| --- | --- | --- |
| 1 | Una API dividida en partes con nombre | Poco: casi siempre conviene |
| 2 | Caché en `GET`, reintentos seguros, códigos que entienden las herramientas | Disciplina para elegir bien método y código |
| 3 | Clientes que descubren las acciones posibles y servidor libre de cambiar sus URLs | Más trabajo en servidor y cliente; pocos clientes lo aprovechan |

## Confusiones frecuentes

- **"Si uso sustantivos en las URLs y los métodos HTTP, mi API es REST."** Eso es el nivel 2 de Richardson. Fielding es explícito: sin hipertexto no es REST. Fowler aclara que el modelo de Richardson es una forma de aprender las ideas de REST, no una definición de niveles de REST.
- **"Para que sea REST hay que estar en el nivel 3."** Para cumplir la definición de Fielding, sí. Para tener una buena API HTTP, el nivel 2 resuelve la mayoría de los problemas de la sección anterior. Muchas APIs públicas se quedan en ese nivel; es una decisión de costo y beneficio, no un error.
- **"`200 OK` con un campo de error es más simple."** Lo es para quien escribe el servidor, pero cada cliente tiene que leer el cuerpo para saber si falló, y los intermediarios ven una respuesta exitosa.
- **"REST significa JSON."** REST no fija un formato. La representación puede ser JSON, XML, HTML u otro, según lo que pidan el cliente y el servidor.

## Ejemplo

Dominio de pedidos con Java 21 y Spring Boot 3. El fragmento es ilustrativo: omite los `import` y las clases de dominio.

La API en **nivel 2**. Crear un pedido responde `201 Created` con `Location`, y los errores de negocio usan el formato del RFC 9457:

```java
@RestController
@RequestMapping("/pedidos")
class PedidoController {
    private final RealizarPedido realizarPedido;

    PedidoController(RealizarPedido realizarPedido) {
        this.realizarPedido = realizarPedido;
    }

    @PostMapping
    ResponseEntity<PedidoResponse> crear(@RequestBody PedidoRequest request) {
        var pedido = realizarPedido.realizar(request.clienteId(), request.lineas());
        var ubicacion = URI.create("/pedidos/" + pedido.id());
        return ResponseEntity.created(ubicacion).body(PedidoResponse.de(pedido));
    }

    @ExceptionHandler(IllegalStateException.class)
    ProblemDetail conflicto(IllegalStateException e) {
        var problema = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, e.getMessage());
        problema.setTitle("El pedido no admite esta operación");
        return problema;
    }
}
```

Las respuestas que recibe el cliente:

```text
POST /pedidos
HTTP/1.1 201 Created
Location: /pedidos/7f3c...

POST /pedidos/7f3c.../cancelacion   (el pedido ya se envió)
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{"type": "about:blank", "title": "El pedido no admite esta operación",
 "status": 409, "detail": "No se puede cancelar un pedido enviado"}
```

Para llegar al **nivel 3**, la respuesta de `GET /pedidos/7f3c...` incluiría un enlace a `cancelacion` solo mientras el pedido se pueda cancelar. Spring HATEOAS ofrece clases para construir esos enlaces.

En C# con .NET 8, `Results.Created(...)` y `Results.Problem(...)` cumplen el mismo papel en Minimal APIs, y `ProblemDetails` implementa el mismo RFC.

## Referencias

- Fielding, R. T. (2000). *Architectural Styles and the Design of Network-based Software Architectures* (tesis doctoral). University of California, Irvine. Cap. 5, *Representational State Transfer (REST)*. <https://ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm> (consultado el 2026-10-29; [copia archivada](https://web.archive.org/web/20261012171929/https://ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm)). Restricciones del estilo e interfaz uniforme.
- Fielding, R. T. (2008). *REST APIs must be hypertext-driven*. <https://roy.gbiv.com/untangled/2008/rest-apis-must-be-hypertext-driven> (consultado el 2026-10-29; [copia archivada](https://web.archive.org/web/20261009013128/https://roy.gbiv.com/untangled/2008/rest-apis-must-be-hypertext-driven)). Sin hipertexto, una API no es REST.
- Fowler, M. (2010). *Richardson Maturity Model*. <https://martinfowler.com/articles/richardsonMaturityModel.html> (consultado el 2026-10-29; [copia archivada](https://web.archive.org/web/20261012195014/https://martinfowler.com/articles/richardsonMaturityModel.html)). Los niveles del modelo, `GET` seguro y caché, `201` con `Location`, `409 Conflict` y la aclaración de que no define niveles de REST.
- Fielding, R., Nottingham, M. y Reschke, J. (2022). *RFC 9110: HTTP Semantics*. <https://www.rfc-editor.org/rfc/rfc9110> (consultado el 2026-10-29; [copia archivada](https://web.archive.org/web/20260520194653/https://www.rfc-editor.org/rfc/rfc9110)). Métodos seguros (9.2.1) e idempotentes (9.2.2) y `201 Created` (15.3.2).
- Nottingham, M., Wilde, E. y Dalal, S. (2023). *RFC 9457: Problem Details for HTTP APIs*. <https://www.rfc-editor.org/rfc/rfc9457> (consultado el 2026-10-29; [copia archivada](https://web.archive.org/web/20260514123618/https://www.rfc-editor.org/rfc/rfc9457)). Formato estándar de errores, que reemplaza al RFC 7807.
- Spring (s. f.). *Error Responses* (Spring Framework Reference). <https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-rest-exceptions.html> (consultado el 2026-10-29; [copia archivada](https://web.archive.org/web/20260918205837/https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-ann-rest-exceptions.html)). Soporte del RFC 9457 con `ProblemDetail`.

Última revisión: 2026-10-29
