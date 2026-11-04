# Sesiones con estado y tokens JWT

<!-- cspell:words Sakimura Bradley Lodderstedt Fett Labunets Sheffer HttpOnly SameSite localStorage sessionStorage JWT JWS JWE claims refresh tokens token revocar revocación rotativos rotativo opaco opacos entropía criptográfico -->

> **Tipo de página:** explicación. Te ayuda a decidir cómo reconoce tu servidor a un usuario ya autenticado y qué cuesta cada opción; no es una guía de un *framework* concreto.

## El problema

El usuario demuestra quién es una vez, con su contraseña. HTTP no guarda memoria entre peticiones, así que en la siguiente petición el servidor necesita volver a reconocerlo sin pedirle la contraseña otra vez. Hay dos familias de soluciones y mezclarlas sin entender sus costos es una fuente habitual de fallos de seguridad.

## La idea central

**Sesión con estado.** El servidor guarda los datos de la sesión (quién es el usuario, cuándo entró) y entrega al navegador un identificador opaco, normalmente en una cookie. En cada petición el servidor busca ese identificador y recupera los datos. OWASP pide que el identificador no tenga significado propio y que tenga al menos 64 bits de entropía, para que no se pueda adivinar ni contenga información que revelar.

**Token firmado (JWT).** El servidor entrega un token que **lleva los datos consigo**. Según el RFC 7519, un JWT es un formato compacto para transportar afirmaciones (*claims*) sobre un sujeto, como un objeto JSON protegido con una firma (JWS) o cifrado (JWE). El RFC define afirmaciones registradas, entre ellas quién lo emitió (`iss`), de quién habla (`sub`), para quién es (`aud`), cuándo caduca (`exp`) y un identificador único (`jti`). Quien recibe el token verifica la firma y no necesita consultar una base de datos.

La diferencia de fondo es **dónde vive el estado**: en la sesión, en el servidor; en el JWT puro, dentro del token que tiene el cliente.

## Cómo se estructura

```mermaid
sequenceDiagram
    participant N as Navegador
    participant S as Servidor
    participant A as Almacén de sesiones
    N->>S: POST /login (usuario y contraseña)
    S->>A: crea la sesión
    S-->>N: Set-Cookie: sid=opaco; HttpOnly; Secure; SameSite
    N->>S: GET /pedidos (cookie sid)
    S->>A: busca sid
    A-->>S: datos del usuario
    S-->>N: 200 OK
```

Con una sesión, la cookie debería llevar tres atributos, que OWASP marca como obligatorios o recomendados:

- `HttpOnly`: el código JavaScript de la página no puede leerla, lo que impide robarla mediante XSS.
- `Secure`: solo viaja por HTTPS.
- `SameSite=Strict` (preferido) o `Lax`: limita que otros sitios la envíen, como defensa adicional contra CSRF, no como sustituto de otras defensas.

OWASP pide también renovar el identificador al iniciar sesión (evita la fijación de sesión), poner un tiempo de inactividad y uno absoluto, aplicados en el servidor, e **invalidar la sesión en el servidor** al cerrar sesión: borrar la cookie del navegador no invalida una copia robada.

Con JWT el flujo cambia: no hay almacén de sesiones en cada petición, pero hay que validar el token. El RFC 8725 recoge las prácticas recomendadas: verificar el algoritmo, validar emisor y sujeto, usar y validar la audiencia y no fiarse de las afirmaciones recibidas sin comprobarlas.

La revocación es la diferencia práctica más importante. El RFC 7519 no define ningún mecanismo para invalidar un token antes de su `exp`; solo menciona `jti` para evitar repeticiones. Revocar un JWT puro antes de que caduque exige algo fuera del estándar, como una lista de tokens bloqueados, y esa lista vuelve a ser estado en el servidor.

El RFC 9700 (buenas prácticas de seguridad de OAuth 2.0) añade una exigencia para los clientes públicos, como una aplicación web o móvil: sus *refresh tokens* deben estar vinculados al emisor del token o usar **rotación**, de modo que cada uso entregue uno nuevo y el anterior deje de servir.

## Cuándo no usarlo

- **JWT para una aplicación web que solo usa tu propio servidor.** Una sesión clásica es más simple, se revoca al instante y no pone datos del usuario en manos del cliente.
- **Sesión en servidor cuando hay muchos clientes distintos y servicios que no comparten almacén.** Un token firmado, de vida corta, evita que cada servicio consulte el mismo almacén.
- **Un JWT para guardar lo que cambia a menudo.** Los datos viajan en el token hasta que caduca; si el rol del usuario cambia, el token antiguo sigue diciendo lo anterior.
- **Tokens en `localStorage` o `sessionStorage`.** OWASP indica no guardar identificadores de sesión ni credenciales ahí, porque cualquier JavaScript del origen puede leerlos y un solo XSS expone todos los tokens.

## Qué se gana y qué se pierde

| | Sesión con estado | JWT |
| --- | --- | --- |
| Dónde está el estado | En el servidor | En el token |
| Revocación | Inmediata: se borra la sesión | No definida en el estándar: hace falta una lista de bloqueo |
| Costo por petición | Una consulta al almacén | Verificar la firma |
| Datos en manos del cliente | Solo un identificador opaco | Todas las afirmaciones, legibles |
| Escalar a varios servicios | Hay que compartir el almacén | Cualquiera con la clave puede validar |

## Confusiones frecuentes

- **"Un JWT en `localStorage` es más seguro y moderno que una cookie de sesión."** Es más expuesto: cualquier XSS puede leer `localStorage`. Una cookie `HttpOnly` no es legible desde JavaScript.
- **"Con JWT se cierra sesión al instante."** Borrar el token del cliente no lo invalida: quien tenga una copia puede seguir usándolo hasta `exp`.
- **"El JWT está cifrado."** Un JWT firmado (JWS) es legible por cualquiera que lo tenga; la firma garantiza que no se alteró, no que sea secreto. El RFC 7519 contempla el cifrado (JWE) como otra opción.
- **"Si el token tiene firma válida, es de confianza."** También hay que comprobar emisor, audiencia y expiración, como pide el RFC 8725.
- **"JWT y OAuth son lo mismo."** OAuth 2.0 es un marco para delegar acceso; los tokens que emite pueden ser JWT u opacos.

## Ejemplo

Dominio de pedidos. `PedidoController` lo consumen una aplicación web propia y una aplicación móvil. El fragmento es ilustrativo y no está compilado.

Para la web propia, una sesión en servidor con cookie endurecida. Con Spring Boot se fija en `application.yml`:

```yaml
server:
  servlet:
    session:
      cookie:
        http-only: true
        secure: true
        same-site: strict
      timeout: 15m
```

Para el cliente móvil y otros servicios, un token de acceso de vida corta junto a un *refresh token* rotativo. La decisión no sale de un estándar: el RFC 9700 exige rotación o vinculación del *refresh token* para clientes públicos, pero no fija cuánto debe durar el token de acceso. La duración (en la práctica, minutos) es una decisión del equipo según cuánto tiempo tolera que un token robado siga funcionando.

Al validar el token en `PedidoController`, el servicio comprueba, como mínimo: la firma con el algoritmo que él espera (no el que diga el propio token), `iss`, `aud` y `exp`.

En .NET 8 la estructura es la misma: autenticación con cookie para la web propia y el *middleware* de autenticación por portador (*bearer*) para los tokens.

## Referencias

- Jones, M., Bradley, J. y Sakimura, N. (2015). *RFC 7519: JSON Web Token (JWT)*. <https://www.rfc-editor.org/rfc/rfc7519> (consultado el 2026-11-04). Definición de JWT, JWS y JWE y las afirmaciones registradas; no define revocación.
- Sheffer, Y., Hardt, D. y Jones, M. (2020). *RFC 8725: JSON Web Token Best Current Practices*. <https://www.rfc-editor.org/rfc/rfc8725> (consultado el 2026-11-04). Sección 3: verificación de algoritmo, emisor, sujeto y audiencia, y no confiar en las afirmaciones recibidas.
- Lodderstedt, T., Bradley, J., Labunets, A. y Fett, D. (2025). *RFC 9700: Best Current Practice for OAuth 2.0 Security*. <https://www.rfc-editor.org/rfc/rfc9700> (consultado el 2026-11-04). Sección 2.2.2: *refresh tokens* de clientes públicos vinculados al emisor o con rotación.
- OWASP (s. f.). *Session Management Cheat Sheet*. <https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html> (consultado el 2026-11-04). Identificador opaco y con entropía, atributos de la cookie, renovación, expiración, invalidación en el servidor y no usar `localStorage`.

Última revisión: 2026-11-04
