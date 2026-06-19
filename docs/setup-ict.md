# Definition du setup ICT

Ce document servira a definir precisement le setup que l'indicateur devra detecter.

## Setup bullish

### Timeframe

- Le setup est toujours analyse en M15.

### Idee generale

Le setup bullish a identifier est compose de deux elements :

1. Un breaker block M15.
2. Un pullback du prix sur ce breaker block.

### Definition trading du breaker block

Dans ce setup, le breaker block vient d'abord d'un order block M15.

### Definition de l'order block pour ce projet

Pour le setup bullish, l'order block M15 correspond a la derniere bougie baissiere, ou a la derniere sequence de bougies baissieres consecutives, juste avant l'impulsion haussiere qui cree le BISI/FVG.

Regle importante :

- si plusieurs bougies baissieres consecutives precedent l'impulsion et le BISI, elles peuvent former une zone OB plus large ;
- si une bougie haussiere apparait avant la derniere bougie baissiere, elle coupe la sequence et ne fait pas partie de l'OB ;
- dans l'exemple fourni, seule la derniere bougie rouge est retenue comme OB, car la bougie precedente est haussiere.

Sequence attendue :

1. Un order block M15 se forme.
2. Cet order block est suivi d'un Fair Value Gap haussier, appele BISI.
3. Le marche se retourne ensuite.
4. Le prix traverse l'order block dans le sens inverse, avec une baisse.
5. L'order block casse devient alors un breaker block.

### Pullback attendu

Apres la cassure de l'order block et sa transformation en breaker block, le prix doit remonter vers la zone du breaker block.

L'alerte ne doit pas se declencher au moment de la cassure.
Elle doit se declencher uniquement lorsque le pullback revient toucher ou atteindre la zone du breaker block.

Dans l'exemple DAX M15 fourni :

- le BISI/FVG se forme apres l'impulsion haussiere ;
- la zone du breaker block est encadree en bleu ;
- le prix casse ensuite cette zone a la baisse avec des bougies rouges ;
- le pullback revient ensuite dans la zone du breaker block ;
- l'alerte doit se declencher a ce retour dans la zone BB.

### Actifs

L'indicateur devra permettre de choisir les actifs a surveiller.

Exemples possibles :

- DAX
- GOLD
- EURUSD
- autres actifs choisis manuellement

La liste exacte des actifs devra etre configurable dans les parametres de l'indicateur.

## Setup bearish

A definir.

## Conditions obligatoires

A definir.

## Conditions optionnelles

A definir.

## Invalidations

A definir.

## Moment de declenchement de l'alerte

Pour le setup bullish, l'alerte doit se declencher au moment ou le prix revient en pullback sur le breaker block M15.

L'alerte attendue :

- alerte sonore dans MetaTrader 5
- alerte visuelle dans MetaTrader 5
- message indiquant l'actif, la timeframe M15 et le type de setup detecte

## Points a preciser avant codage

Pour transformer cette definition en indicateur, il faudra preciser :

1. Comment identifier exactement l'order block M15.
2. Comment valider exactement le BISI apres l'order block.
3. Combien de bougies maximum peuvent separer l'order block et le BISI.
4. Ce qui confirme que l'order block est casse et devient breaker block.
5. Si l'alerte doit se declencher au premier contact du breaker block, a l'entree dans la zone, ou a la cloture d'une bougie dans la zone.
6. Si une alerte doit etre envoyee une seule fois par breaker block ou plusieurs fois a chaque retour du prix.
7. Si la zone OB doit etre tracee avec les meches completes ou uniquement avec les corps des bougies.
