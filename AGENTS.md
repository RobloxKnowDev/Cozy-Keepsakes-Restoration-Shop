# Règles de code du projet

- Ne pas mettre de commentaires dans les scripts.
- Utiliser directement la hiérarchie fournie avec `WaitForChild`.
- Ne pas ajouter de fonctions de recherche génériques ni de vérifications défensives quand l'organisation des objets est connue.
- Préférer un accès simple et lisible, par exemple `local Button = Card:WaitForChild("Button")`.
- Si un nom dans la hiérarchie est incorrect, laisser l'erreur apparaître clairement pour qu'elle puisse être corrigée.
