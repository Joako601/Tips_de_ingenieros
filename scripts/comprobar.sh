#!/usr/bin/env bash
# Corre en local los mismos chequeos que el workflow calidad.yml antes de abrir un PR.
#
# Uso:
#   scripts/comprobar.sh                       corre todos
#   scripts/comprobar.sh referencias           corre solo los que nombres
#
# Chequeos: referencias, ortografia, markdown, prosa, enlaces.
# Las carpetas de contenido y las versiones de cspell se leen de calidad.yml para no duplicarlas.
# El script no descarga ni ejecuta binarios sueltos: vale y lychee se usan solo si ya están instalados.

set -u
cd "$(git rev-parse --show-toplevel)" || exit 2

FLUJO=.github/workflows/calidad.yml
MARKDOWNLINT_CLI2=0.24.0   # la versión que trae markdownlint-cli2-action v25.0.0

todos=(referencias ortografia markdown prosa enlaces)
pedidos=("$@")
[ "${#pedidos[@]}" -eq 0 ] && pedidos=("${todos[@]}")

correctos=()
fallidos=()
omitidos=()

encabezado() { printf '\n==> %s\n' "$1"; }

referencias() {
  local carpetas faltan=0 archivo
  carpetas=$(sed -n 's/.*done < <(find \(.*\) -name .*/\1/p' "$FLUJO")
  [ -n "$carpetas" ] || { echo "No encontré la lista de carpetas en $FLUJO"; return 1; }
  # shellcheck disable=SC2086
  while IFS= read -r archivo; do
    if ! grep -q '^## Referencias' "$archivo"; then
      echo "Falta la sección '## Referencias': $archivo"
      faltan=1
    fi
  done < <(find $carpetas -name '*.md' 2>/dev/null)
  return "$faltan"
}

ortografia() {
  local paquetes
  paquetes=$(sed -n 's/.*run: npm install --no-save --no-audit --no-fund \(.*\)/\1/p' "$FLUJO")
  [ -n "$paquetes" ] || { echo "No encontré la instalación de cspell en $FLUJO"; return 1; }
  # shellcheck disable=SC2086
  npm install --no-save --no-audit --no-fund $paquetes >/dev/null || return 1
  npx cspell --no-progress --gitignore "**/*.md"
}

markdown() {
  npx --yes "markdownlint-cli2@$MARKDOWNLINT_CLI2" "**/*.md"
  local salida=$?
  if [ "$salida" -ge 128 ] && command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    # Con algunas versiones de Node el binario se cae (código 139). Se repite dentro de un contenedor.
    echo "markdownlint-cli2 se cayó con el Node local (código $salida); lo repito con Docker."
    docker run --rm -v "$PWD":/trabajo -w /trabajo node:22-slim \
      npx --yes "markdownlint-cli2@$MARKDOWNLINT_CLI2" "**/*.md"
    return $?
  fi
  return "$salida"
}

prosa() {
  command -v vale >/dev/null || return 99
  vale --minAlertLevel=error .
}

enlaces() {
  command -v lychee >/dev/null || return 99
  lychee --config lychee.toml --no-progress "**/*.md"
}

for nombre in "${pedidos[@]}"; do
  case " ${todos[*]} " in
    *" $nombre "*) ;;
    *) echo "Chequeo desconocido: $nombre (los válidos son: ${todos[*]})"; exit 2 ;;
  esac
  encabezado "$nombre"
  "$nombre"
  salida=$?
  case "$salida" in
    0)  correctos+=("$nombre") ;;
    99) echo "Omitido: falta una herramienta que este script no instala."; omitidos+=("$nombre") ;;
    *)  fallidos+=("$nombre") ;;
  esac
done

printf '\n==> Resumen\n'
[ "${#correctos[@]}" -gt 0 ] && echo "Correctos: ${correctos[*]}"
[ "${#omitidos[@]}" -gt 0 ] && echo "Omitidos:  ${omitidos[*]} (instala vale y lychee para correrlos; el CI sí los corre)"
[ "${#fallidos[@]}" -gt 0 ] && echo "Fallidos:  ${fallidos[*]}"
[ "${#fallidos[@]}" -eq 0 ]
