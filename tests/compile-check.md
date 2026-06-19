# Verification de compilation

## Version controlee

- Fichier : `src/SETUP_BBM15.mq5`
- Date : 2026-06-19
- Outil : MetaEditor64

## Resultat

Compilation effectuee avec MetaEditor.

Resultat :

- erreurs : 0
- avertissements : 0
- fichier compile genere localement : `src/SETUP_BBM15.ex5`

## Scanner EA

- Fichier : `src/SETUP_BBM15_Scanner_EA.mq5`
- Type : Expert Advisor scanner, sans trading automatique
- Version actuelle : 1.001
- Option ajoutee : affichage des fleches historiques sur le graphique actif
- Resultat compilation : 0 erreur, 0 avertissement
- Fichier compile genere localement : `src/SETUP_BBM15_Scanner_EA.ex5`

## Variante DOB

- Fichier indicateur : `src/DisplacementOrderBlock.mq5`
- Source externe : `rpanchyk/mt5-dob-ind`, licence MIT
- Resultat compilation indicateur : 0 erreur, 0 avertissement
- Fichier compile genere localement : `src/DisplacementOrderBlock.ex5`

- Fichier EA : `src/SETUP_BBM15_DOB_Scanner_EA.mq5`
- Type : Expert Advisor scanner, sans trading automatique, base sur les buffers DOB
- Resultat compilation EA : 0 erreur, 0 avertissement
- Fichier compile genere localement : `src/SETUP_BBM15_DOB_Scanner_EA.ex5`

## Notes

L'installation dans le dossier `MQL5/Indicators` a ete faite manuellement pour l'ancienne version indicateur.

Pour les scanners EA, les fichiers doivent etre installes dans `MQL5/Experts`.

Pour la variante DOB, `DisplacementOrderBlock` doit etre installe dans `MQL5/Indicators` avant d'attacher `SETUP_BBM15_DOB_Scanner_EA` au graphique.

Verification apres copie :

- `SETUP_BBM15.mq5` est present dans `MQL5/Indicators`
- `SETUP_BBM15.ex5` est present dans `MQL5/Indicators`
- le hash SHA256 du `.ex5` installe est identique au `.ex5` compile dans le projet

La compilation lancee directement depuis `MQL5/Indicators` lit correctement le source, mais MetaEditor retourne `EX5 write error` au moment de reecrire le fichier compile. Le fichier `.ex5` deja installe reste valide, car il correspond exactement au fichier compile auparavant.
