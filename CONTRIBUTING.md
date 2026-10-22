# Cómo contribuir

Esta guía define cómo trabajamos: ramas, pull requests, mensajes de commit, coautoría, estructura de las páginas y estilo de escritura. Si algo de aquí te parece equivocado, propón el cambio con un pull request que modifique este archivo.

## Flujo de trabajo

1. Crea una rama desde `main` actualizado. Nombre: `tipo/tema-corto`, por ejemplo `docs/hexagonal` o `ci/enlaces`.
2. Haz commits pequeños que sigan [Conventional Commits](#mensajes-de-commit).
3. Abre un pull request. El título también debe ser un Conventional Commit, porque es el mensaje que queda en `main`.
4. La otra persona revisa, comenta y aprueba. Quien abrió el PR responde todas las conversaciones.
5. Se fusiona con **squash and merge**, el único método habilitado. Antes de confirmar, quien fusiona revisa que el mensaje conserve los trailers `Co-authored-by`.

`main` está protegida por un ruleset sin excepciones, ni siquiera para quien administra el repositorio: no se puede hacer push directo ni force push, y el PR necesita una aprobación, todas las conversaciones resueltas y los checks en verde.

## Mensajes de commit

Seguimos [Conventional Commits 1.0.0](https://www.conventionalcommits.org/es/v1.0.0/). El formato es:

```text
tipo(alcance): descripción en minúscula y en imperativo

Cuerpo opcional: qué cambia y por qué.

Co-authored-by: Nombre <correo>
```

| Tipo | Cuándo |
|---|---|
| `docs` | Contenido nuevo o modificado en una página |
| `fix` | Corrección de un error de contenido o de un enlace |
| `ci` | Workflows y configuración de los checks |
| `chore` | Mantenimiento que no cambia el contenido |
| `style` | Formato sin cambio de significado |
| `refactor` | Reorganizar páginas sin cambiar lo que dicen |

Alcances permitidos: `arquitectura`, `principios`, `git`, `repo`, `deps`. El alcance es opcional.

Ejemplo: `docs(arquitectura): agrega la página de arquitectura hexagonal`.

## Coautoría

Cuando una sección se escribe entre los dos, el commit lleva el trailer de quien no hace el commit, al final del mensaje y separado del cuerpo por una línea en blanco:

```text
Co-authored-by: Josspoot <208691436+Josspoot@users.noreply.github.com>
Co-authored-by: Joako601 <242209193+Joako601@users.noreply.github.com>
```

Usamos las direcciones `noreply` de GitHub: quedan vinculadas a cada cuenta y no publican correos personales. El trailer va solo en el trabajo que realmente hicimos juntos.

Después de fusionar, el workflow de `main` valida el mensaje final. Para ver la coautoría en el historial:

```sh
git log --format='%h %s%n%(trailers:key=Co-authored-by)'
```

## Estructura de una página

Cada página del contenido (`arquitectura/`, `principios/`, `git/`) es de un solo tipo según [Diátaxis](https://diataxis.fr/): explicación, referencia o guía práctica. No mezcles tipos en una página.

Usa estas secciones, en este orden:

```markdown
# Nombre de la idea

## El problema
## La idea central
## Cómo se estructura
## Cuándo no usarlo
## Qué se gana y qué se pierde
## Confusiones frecuentes
## Ejemplo
## Referencias

Última revisión: AAAA-MM-DD
```

Un check del CI exige que cada página de contenido tenga la sección `## Referencias`.

## Fuentes y citas

- Escribe con tus palabras. No copies párrafos, ni hagas paráfrasis que sigan la fuente frase por frase, ni redibujes diagramas de libros.
- Prefiere la fuente original del autor (libro, artículo, especificación) antes que resúmenes de blogs.
- Toda cita lleva localizador: capítulo, sección o página en libros; URL y fecha de consulta en la web, más una copia en [web.archive.org](https://web.archive.org/).
- Distingue lo que dice el autor de nuestra interpretación. Si una idea cambió con el tiempo, cuéntalo.
- Quien revisa abre la fuente y comprueba al menos las afirmaciones principales antes de aprobar.

Formato de una referencia:

```markdown
- Cockburn, A. (2005). *Hexagonal Architecture*. https://alistair.cockburn.us/hexagonal-architecture/ (consultado el 2026-10-22).
- Evans, E. (2003). *Domain-Driven Design*. Addison-Wesley, cap. 4.
```

## Estilo de escritura

- Español neutro, con tuteo.
- Oraciones cortas y voz activa. Una idea por párrafo.
<!-- vale TipsDeIngenieros.Relleno = NO -->
- Sin relleno: evita "simplemente", "obviamente" y parecidos.
<!-- vale TipsDeIngenieros.Relleno = YES --> Lo que es obvio para ti no lo es para quien lee.
- Los términos técnicos en inglés van en cursiva la primera vez y se explican, por ejemplo *pull request*.
- Los enlaces describen su destino. Nunca escribas "clic aquí".
- Los diagramas van en Mermaid y las imágenes llevan texto alternativo.
- El código usa Java 21 con Spring Boot 3.x o C# con .NET 8. Si es ilustrativo y no compila, dilo.

### Terminología

<!-- vale off -->
<!-- cspell:disable -->

| Usamos | En lugar de |
|---|---|
| biblioteca | librería |
| desplegar | deployar |
| probar | testear |
| puerto, adaptador | port, adapter (fuera de código) |

<!-- cspell:enable -->
<!-- vale on -->

El linter de prosa (Vale) aplica esta tabla. Para agregar un término, modifica la tabla y `.vale/styles/TipsDeIngenieros/Terminologia.yml` en el mismo PR.

## Checks automáticos

| Check | Qué valida |
|---|---|
| `markdown` | Formato Markdown (markdownlint-cli2) |
| `prosa` | Terminología y palabras de relleno (Vale) |
| `ortografia` | Ortografía en español e inglés (cspell) |
| `enlaces` | Enlaces y anclas rotas (lychee). También corre cada semana |
| `referencias` | Sección `## Referencias` en las páginas de contenido |
| `titulo-pr` | Título del PR en formato Conventional Commits |

Si cspell marca una palabra técnica correcta, agrégala a `cspell.json`.

## Licencia de las contribuciones

Al contribuir aceptas que el texto se publique bajo [CC BY 4.0](LICENSE) y el código bajo [MIT](LICENSE-CODE).

## Decisiones

| Decisión | Motivo |
|---|---|
| Español como idioma | Hay menos referencias de calidad en español con fuentes primarias citadas |
| CC BY 4.0 para texto y MIT para código | Creative Commons desaconseja sus licencias para software |
| Squash and merge como único método | Un commit por PR en `main`, con el título validado y los trailers de coautoría incluidos |
| Ruleset sin excepciones | La regla "nadie hace push a `main`" no depende de la buena voluntad |
| Mermaid para diagramas | Se versionan como texto y se revisan en el diff |
