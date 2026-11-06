#!/usr/bin/env bash
# Avisa de las páginas cuya línea "Última revisión: AAAA-MM-DD" tiene más de N días (365 por defecto)
# o no existe o no se entiende. Termina con código 1 si encuentra alguna.
#
# Uso:
#   scripts/frescura.sh        páginas sin revisar en más de un año
#   scripts/frescura.sh 180    páginas sin revisar en más de 180 días

set -u
cd "$(dirname "$0")/.." || exit 2

dias=${1:-365}
case "$dias" in
  ''|*[!0-9]*) echo "El límite de días debe ser un número: $dias"; exit 2 ;;
esac

hoy=$(date -u +%s)
avisos=0

while IFS= read -r archivo; do
  linea=$(grep -m1 '^Última revisión: ' "$archivo")
  fecha=${linea#Última revisión: }
  if [ -z "$linea" ] || ! [[ "$fecha" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || ! marca=$(date -u -d "$fecha" +%s 2>/dev/null); then
    echo "Sin fecha válida de revisión: $archivo"
    avisos=$((avisos + 1))
    continue
  fi
  edad=$(( (hoy - marca) / 86400 ))
  if [ "$edad" -gt "$dias" ]; then
    echo "Hace $edad días que no se revisa ($fecha): $archivo"
    avisos=$((avisos + 1))
  fi
done < <(find $(sh scripts/carpetas.sh) -name '*.md' | sort)

[ "$avisos" -eq 0 ] && echo "Todas las páginas se revisaron hace $dias días o menos."
[ "$avisos" -eq 0 ]
