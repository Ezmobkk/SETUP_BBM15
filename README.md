# SETUP_BBM15

Scanner MetaTrader 5 pour detecter un setup ICT specifique et envoyer des alertes visuelles et sonores.

## Objectif

Ce projet vise a construire un assistant d'alerte MT5, pas un robot de trading automatique.
L'outil sert uniquement a reperer un setup defini, puis a alerter le trader.

La version principale est maintenant un Expert Advisor scanner sans aucune fonction d'achat ou de vente.
Il peut tourner en arriere-plan et surveiller une liste d'actifs definie manuellement.

## Structure

- `docs/` : cahier des charges, definition du setup, journal des decisions.
- `src/` : code source MQL5 de l'indicateur et du scanner EA.
- `tests/` : scenarios de verification et captures de test.
- `releases/` : versions livrables de l'indicateur.

## Fichiers principaux

- `src/SETUP_BBM15_Scanner_EA.mq5` : scanner multi-actifs sans trading automatique.
- `src/SETUP_BBM15_DOB_Scanner_EA.mq5` : nouvelle variante EA qui lit l'indicateur `DisplacementOrderBlock`.
- `src/DisplacementOrderBlock.mq5` : indicateur DOB/OB externe utilise par la variante DOB.
- `src/SETUP_BBM15.mq5` : ancienne version indicateur graphique.

## Installation de la variante DOB

1. Copier `DisplacementOrderBlock.mq5` et `DisplacementOrderBlock.ex5` dans `MQL5/Indicators`.
2. Copier `SETUP_BBM15_DOB_Scanner_EA.mq5` et `SETUP_BBM15_DOB_Scanner_EA.ex5` dans `MQL5/Experts`.
3. Dans MT5, rafraichir le Navigateur.
4. Attacher `SETUP_BBM15_DOB_Scanner_EA` sur un graphique.

Cette variante ne passe aucun ordre. Elle utilise l'indicateur DOB pour reperer les OB, puis l'EA cherche la cassure inverse et le pullback sur le bas du breaker block.

## Source externe

`DisplacementOrderBlock.mq5` provient du projet public MIT `rpanchyk/mt5-dob-ind`.
