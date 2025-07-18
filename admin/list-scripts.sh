 
#!/bin/bash

# Script pour lister tous les scripts du dossier ~/scripts
# Auteur: NDXDev@gmail.com
# Date: $(date +%Y-%m-%d)

SCRIPTS_DIR="$HOME/scripts"

echo "==================================="
echo "    SCRIPTS DISPONIBLES"
echo "==================================="
echo

# Vérifier si le dossier existe
if [ ! -d "$SCRIPTS_DIR" ]; then
    echo "❌ Le dossier $SCRIPTS_DIR n'existe pas!"
    exit 1
fi

# Compter le nombre de scripts
script_count=0

echo "📁 Dossier: $SCRIPTS_DIR"
echo

# Lister les fichiers .sh avec des détails
for script in "$SCRIPTS_DIR"/*.sh; do
    if [ -f "$script" ]; then
        filename=$(basename "$script")

        # Vérifier si le script est exécutable
        if [ -x "$script" ]; then
            status="✅ Exécutable"
        else
            status="❌ Non exécutable"
        fi

        # Obtenir la taille du fichier
        size=$(du -h "$script" | cut -f1)

        # Obtenir la date de modification
        mod_date=$(stat -c %y "$script" | cut -d' ' -f1)

        echo "📄 $filename"
        echo "   └─ $status | Taille: $size | Modifié: $mod_date"
        echo

        ((script_count++))
    fi
done

# Si aucun script trouvé
if [ $script_count -eq 0 ]; then
    echo "ℹ️  Aucun script (.sh) trouvé dans $SCRIPTS_DIR"
else
    echo "==================================="
    echo "📊 Total: $script_count script(s) trouvé(s)"
fi

echo "==================================="
