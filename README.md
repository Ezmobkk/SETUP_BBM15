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
- `src/SETUP_BBM15.mq5` : ancienne version indicateur graphique.
