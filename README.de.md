---
description: "Native macOS-Mitteilungen, Genehmigungen, Frageformulare und eine Sitzungsübersicht für DSH Desktop."
kind: "package-reference"
---

# DSH Notify

[简体中文](README.md) · [English](README.en.md) · [日本語](README.ja.md) · [Español](README.es.md) · [Français](README.fr.md) · **Deutsch** · [Русский](README.ru.md) · [Português](README.pt.md)

Ergänzt **DeepSeek Harness Desktop** um native macOS-Mitteilungen, Genehmigungen, Frageformulare und eine Sitzungsübersicht in der Menüleiste. Bearbeiten Sie eine Anfrage direkt aus der Mitteilung oder wechseln Sie zum zugehörigen Arbeitsbereich und zur richtigen Sitzung.

Das Projekt besteht aus einem DSH-Plugin und dem Hintergrundhelfer **DSH Notify.app**. Der Helfer startet und endet mit Desktop. Browser, DSH Bridge und zusätzliche Modelldienste sind nicht erforderlich. Dies ist ein Community-Plugin; die aktuelle stabile Version ist **v0.5.0**. Siehe [Versionen und Downloads](https://github.com/realDGD/dsh-macos-notify/releases/tag/v0.5.0).

## Funktionen

| Funktion | Verhalten |
| --- | --- |
| Native Mitteilungen | Meldet Abschluss, Fehler, Genehmigungen und Fragen. Ein Klick öffnet die passende Sitzung. |
| Schnelle Genehmigung | Wählen Sie **Einmal zulassen** oder **Ablehnen** in Mitteilung oder Menü. Die Details zeigen den auszuführenden Befehl. |
| Vollständige Frageformulare | Eine Mitteilung öffnet alle Fragen mit Einfach-/Mehrfachauswahl, getrennten Textfeldern und gemeinsamem Versand. |
| Sitzungsübersicht | Zeigt Aktivität, verschachtelte Subagenten und die fünf letzten Hauptsitzungen mit Status und Fortschritt. |
| Kontext und Code | Rendert Markdown-Tabellen, Formeln und Code lokal, mit Shell-/JSON-Hervorhebung und Zeilenumbruch für Befehle und Argumente. |
| Sprachen | Folgt DSH in vereinfachtem Chinesisch, Englisch, Japanisch, Spanisch, Französisch, Deutsch, Russisch und Portugiesisch. Namen, Fragen, Optionen, Antworten und Befehle bleiben im Original. |

Die sechs ergänzten Sprachen sind im aktuellen Quellcode enthalten und noch nicht als stabile Version veröffentlicht. Bauen Sie den nativen Helfer aus derselben Revision neu, um sie zu verwenden. Siehe [Terminologie und Pflege](docs/localization.md).

DSH entscheidet, ob eine Anfrage noch gültig ist. Die zuerst akzeptierte Antwort gilt; beantwortete, abgebrochene oder abgelaufene Anfragen werden zurückgezogen. Alte Schaltflächen führen keine Aktion doppelt aus. Das Schließen eines Fragenfensters oder eine kurze Trennung erhält Entwürfe. **Antworten löschen** entfernt Auswahl und Text, ohne die Anfrage abzubrechen. Entwürfe liegen nur im Arbeitsspeicher des Helfers und werden nach bestätigter Antwort, Abbruch oder Rücknahme gelöscht. Beim Beenden des Helfers gehen ungesendete Entwürfe verloren. Unbestätigte Ergebnisse werden niemals automatisch erneut gesendet.

## Ansichten

**Die folgenden Bilder und Aufnahmen zeigen die englische Oberfläche als Beispiel. Das Plugin bietet auch eine deutsche Oberfläche.** Es sind echte native Aufnahmen mit erfundenen Arbeitsbereichen, Sitzungen und Anfragen. Systemelemente der Mitteilungszentrale folgen der macOS-Sprache. Klicken Sie auf ein Bild für die volle Größe. Siehe [Bildquellen und Umfang](docs/images/README.md).

### Sitzungen und Schnellaktionen

<table>
<tr><th>Sitzungsmenü</th><th>Zustände und Animation des Fischsymbols</th></tr>
<tr>
<td valign="top"><a href="docs/images/menu-sessions-en.png"><img src="docs/images/menu-sessions-en.png" alt="Englisches Beispiel mit aktiven und letzten Sitzungen, Genehmigungen und Fragen" width="400"></a></td>
<td valign="top"><a href="docs/images/menu-icon-states-en.gif"><img src="docs/images/menu-icon-states-en.gif" alt="Englisches Beispiel der Symbolzustände und Fischrotation" width="400"></a></td>
</tr>
</table>

Der Fisch dreht sich bei laufenden Aufgaben. Orange steht für Genehmigungen oder Fragen, Rot für ungewöhnliche Unterbrechung, Grün für Abschluss. Priorität: **Eingabe erforderlich > ungewöhnlicher Stopp > Abschluss**. Das Öffnen der Übersicht setzt das Symbol auf Weiß zurück. Ein Benutzerstopp erzeugt keine Fehlermeldung.

### Genehmigungen und Details

<table>
<tr><th>Mitteilung und Aktionen</th><th>Befehle und Berechtigungen prüfen</th></tr>
<tr>
<td valign="top"><a href="docs/images/notification-approval-en.png"><img src="docs/images/notification-approval-en.png" alt="Englische Genehmigungsmitteilung mit Zulassen, Ablehnen und Details" width="400"></a></td>
<td valign="top"><a href="docs/images/approval-details-en.png"><img src="docs/images/approval-details-en.png" alt="Englisches Detailfenster mit Befehl, vollständigen Argumenten und Kontext" width="400"></a></td>
</tr>
</table>

**Details anzeigen** öffnet Grund, Befehl, vollständige Argumente und Kontext. Argumente werden eingerückt und lange Zeilen umgebrochen. **Original anzeigen** und **Ursprüngliche Argumente kopieren** erhalten den Originalinhalt. Die Darstellung verändert die an DSH gesendete Anfrage nicht.

### Fragen und Formulare

<table>
<tr><th>Fragenmitteilung</th><th>Auswahl und Text je Frage</th></tr>
<tr>
<td valign="top"><a href="docs/images/notification-questionnaire-en.png"><img src="docs/images/notification-questionnaire-en.png" alt="Englisches Beispiel einer Mitteilung mit zwei Fragen" width="400"></a></td>
<td valign="top"><a href="docs/images/questionnaire-en.png"><img src="docs/images/questionnaire-en.png" alt="Englisches Formular mit Einfach-/Mehrfachauswahl, getrennten Textfeldern und gemeinsamem Versand" width="400"></a></td>
</tr>
</table>

**Fragen öffnen** zeigt das gesamte Formular; **Alle Antworten senden** sendet es gemeinsam. Eine vorherige Antwort in DSH macht die alte Mitteilung ungültig. **In DSH öffnen** schließt das Fenster, nachdem die richtige Sitzung bestätigt wurde. Die Beispiele führen keine Befehle aus, rufen kein Modell auf und senden keine echten Antworten.

<a id="installation"></a>

## Installation

**Empfohlen ist der Plugin-Manager von DSH Desktop.** Benötigt werden macOS 13 oder neuer, offizielles DSH Desktop und Apple Command Line Tools. Laufzeitkompatibilität und Helferstatus wurden mit `0.2.2-rc.1` geprüft. Desktop verwendet sein mitgeliefertes Node.js/pnpm. Ein separates Node.js 22+ ist nur für manuelle Builds und Entwicklung nötig. Grenzen für ältere macOS-Versionen, Intel und echte Mitteilungsklicks stehen unter [Kompatibilität](docs/compatibility.md).

`v0.5.0` installiert den Helfer automatisch; `v0.5.0-preview.1` benötigt die manuellen Schritte. Beachten Sie für die neuen Sprachen auch den Hinweis zum Quellcode oben.

1. Führen Sie dies im Terminal aus und schließen Sie die Systeminstallation ab. Bereits installierte Tools können Sie weiterverwenden. Vollständiges Xcode und ein kostenpflichtiges Zertifikat sind unnötig.

   ```sh
   xcode-select --install
   ```

2. Öffnen Sie **Plugins → Plugin hinzufügen**, fügen Sie diese Adresse ein, prüfen Sie die Quelle und wählen Sie **Installieren**:

   ```text
   github:realDGD/dsh-macos-notify
   ```

3. Falls Build-Skripte blockiert werden, prüfen Sie das Plugin, erlauben Sie die Skripte und versuchen Sie es erneut. Der Helfer wird unter `/Applications/DSH Notify.app` gebaut. Ein passender Build wird wiederverwendet; Updates behalten Einstellungen und sichern die alte Anwendung.
4. Wählen Sie **Jetzt aktivieren**. Speichern Sie Ihre Arbeit, beenden Sie Desktop mit **⌘Q** und öffnen Sie es erneut. Ein geschlossenes Fenster beendet die Anwendung nicht. Erlauben Sie Mitteilungen für **DSH Notify**, wenn macOS fragt.
5. Prüfen Sie unter **Einstellungen → DSH Notify** Verbindung und Berechtigung. Senden Sie die Testmitteilung und klicken Sie darauf, um die richtige Sitzung zu prüfen. Die Annahme durch macOS bestätigt nur die Annahme zur Zustellung; erst der Klick prüft die Navigation.

Siehe den [offiziellen Plugin-Leitfaden](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/client/ui-plugin-manager/README.md).

### Terminalbefehl

Installieren Sie den Befehl über **Manage dsh Command…** im Desktop-App-Menü und führen Sie in einem neuen Terminal aus:

```sh
dsh plugin --profile desktop add github:realDGD/dsh-macos-notify
```

Desktop nutzt das Profil `desktop`; `--profile web` betrifft eine getrennte Web-Umgebung. Erlauben Sie blockierte Skripte über den Plugin-Manager. Siehe [Installationsdetails](docs/install.md) und [offiziellen Befehlsleitfaden](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/desktop/README.md#terminal-command).

### DSH um Unterstützung bitten

Kopieren Sie dies in eine neue Unterhaltung:

```text
Installiere DSH Notify im offiziellen DeepSeek Harness Desktop auf diesem Mac:
https://github.com/realDGD/dsh-macos-notify
Lies zuerst README und docs/install.md. Prüfe DSH-Version, macOS 13+ und Command Line Tools.
Verwende das Profil desktop und den Plugin-Manager oder den mitgelieferten dsh-Befehl.
Prüfe, ob die Version die benötigte Sprache enthält, und baue /Applications/DSH Notify.app aus derselben Revision wie das Plugin.
Erhalte Einstellungen und vorhandene Sicherungen. Erkläre nötige Schritte für Systeminstallation, Skriptfreigabe und Mitteilungsberechtigung.
Bitte mich, Arbeit zu speichern und Desktop zu beenden und neu zu öffnen. Führe mich durch das Senden und Anklicken der Testmitteilung bis zur Prüfung der passenden Sitzung.
```

### Manuelle Installation

Für ältere Vorschauen, fehlgeschlagene automatische Installation oder Entwicklung: Installieren Sie Command Line Tools und [Node.js 22+](https://nodejs.org/en/download), dann:

```sh
git clone https://github.com/realDGD/dsh-macos-notify.git
cd dsh-macos-notify
npm ci --ignore-scripts
bash macos/install.sh
pwd
```

Fügen Sie den absoluten Pfad von `pwd` unter **Plugins → Plugin hinzufügen** ein. Aktivieren, neu starten und testen. Alternativ entpacken Sie ein vollständiges Quellarchiv von [Releases](https://github.com/realDGD/dsh-macos-notify/releases) und beginnen bei `npm ci --ignore-scripts`. Plugin und Helfer müssen dieselbe Revision haben. Das offizielle Symbol stammt normalerweise aus `/Applications/DeepSeek Harness.app`; abweichende Pfade beschreibt die [Anleitung](docs/install.md).

### Häufige Probleme

| Problem | Lösung |
| --- | --- |
| `swiftc` fehlt | Systeminstallation von `xcode-select --install` abschließen und erneut versuchen. |
| Skripte blockiert | Skripte in DSH erlauben und erneut versuchen. |
| `dsh` nicht gefunden | Plugin-Manager verwenden oder Befehl in Desktop reparieren und neues Terminal öffnen. |
| Inkompatible Version | Passende Versionen gemäß [Kompatibilität](docs/compatibility.md) wählen. |
| Helfer fehlt oder Update abgelehnt | Manuell installieren oder Entwürfe bearbeiten und Genehmigungs-/Fragenfenster schließen. |
| GitHub nicht erreichbar | Verbindung prüfen oder vorhandenes vollständiges Quellarchiv verwenden. Ein anderer npm-Registry lädt kein GitHub-Repository herunter. |
| Keine Mitteilung | **Systemeinstellungen → Mitteilungen → DSH Notify** und Fokus prüfen, dann Test senden. |

Der Helfer folgt Desktop und ist kein Anmeldeobjekt.

## Tägliche Verwendung

- Klicken Sie auf den Fisch. Angeheftete Sitzungen, ausstehende Eingaben und ungewöhnliche Stopps stehen vor laufenden Sitzungen. Der Verlauf zeigt bis zu fünf Hauptsitzungen ohne Dubletten oder Subagenten.
- Abschnittslimits zählen nur Hauptsitzungen. Aufklappen zeigt zunächst zwei Subagenten; die zusätzliche Zeile zeigt die übrigen. Die Höhe wächst bis zum Limit, dann dienen Auf-/Abwärtspfeile zur Navigation. Es gibt weder Mausrad-Scrollen noch Scrollleiste. Bei nur einer sichtbaren Zeile wird die Hauptsitzung nicht fixiert.
- Auf/Ab wählt die zusätzliche Subagentenzeile. Eingabe/Leertaste klappt sie auf oder zu; Rechts klappt ebenfalls auf. Danach erhält der erste neue Subagent den Fokus. Links auf dieser Zeile kehrt zum übergeordneten Eintrag zurück.
- Aufgabenzahlen stehen im Fortschrittsring; ein fertiger Plan wird zum grünen Häkchen. Ohne Plan gibt es keinen Ring. Genehmigungsbuttons sind vertikal, Fragen öffnen das Formular. **Aktionen** trennt mehrere Anfragen derselben Sitzung.
- Einstellungen regeln Mitteilungsarten, Ton, separate Subagentenergebnisse, Warten auf deren Abschluss und Stummschaltung während der Sitzungsansicht.
- Rechtsklick bietet DSH öffnen, DSH Notify-Einstellungen, Ausblenden und DSH beenden. Das Zahnrad öffnet die Einstellungen. Ein Klick außerhalb schließt die Übersicht; unabhängige Genehmigungs-/Fragenfenster bleiben offen.
- Beenden verlangt Bestätigung bei laufenden Aufgaben, Genehmigungen, Fragen oder veralteten, unvollständigen beziehungsweise unbekannten Zuständen. Der Helfer fordert ein normales Beenden an.
- Ausblenden lässt Mitteilungen und native Fenster verfügbar. Aktivieren Sie die Leiste wieder in den DSH Notify-Einstellungen.
- Ändern Sie die Sprache in DSH. Offene Fenster aktualisieren Texte und behalten Auswahl und Entwürfe. Bereits zugestellte Mitteilungen behalten die Sendesprache.

Markdown und KaTeX rendern Kontext lokal: Überschriften, Listen, Zitate, Tabellen, Formeln und Code. Externe Bilder werden nicht automatisch geladen, HTML wird nicht ausgeführt. Lange Inhalte zeigen ihr Kürzungslimit; lesen Sie den vollständigen Text in DSH.

## Aktualisieren und entfernen

Speichern Sie Arbeit, bearbeiten Sie Entwürfe und schließen Sie native Fenster vor dem Update. Im aktuellen Plugin-Manager **entfernen Sie das Plugin und fügen es erneut hinzu**. Automatische Installation prüft auch den Helfer. Bei manueller Installation führen Sie `npm ci --ignore-scripts` und `bash macos/install.sh` aus und fügen dasselbe Verzeichnis hinzu. Starten Sie Desktop normal neu. Einstellungen und Sicherungen bleiben erhalten; vor dem Austausch wird das Ende des alten Prozesses bestätigt.

Bei Migration von `dsh-notify-web` / `DSH Jump.app` entfernen Sie das alte Mitteilungsplugin und die Abschluss-/Fehlerweiterleitung gegen doppelte Hinweise. Die historische Helferidentität bleibt für Berechtigungen und Kompatibilität erhalten.

Entfernen Sie zur Deinstallation das Plugin in DSH und führen Sie im Quellverzeichnis aus:

```sh
bash macos/uninstall.sh
```

Starten Sie Desktop neu. Einstellungen und App-Sicherungen bleiben; nur durch diesen Installer verwaltete Dateien werden entfernt.

## Datenschutz und Grenzen

Es entstehen keine zusätzlichen Netzwerk-Listener, Cloud-Dienste oder Modellsitzungen. Navigation und Einstellungen nutzen die authentifizierte DSH-Verbindung und private Benutzerdateien. Fragen und Genehmigungen werden für die Formulare kurzzeitig lokal gespeichert und nicht mit Diagnosen exportiert. Teilen Sie keine lokalen Zustände, Token, Unterhaltungen oder unbereinigten Screenshots echter Daten in Fehlerberichten.

macOS steuert Mitteilungen, Fokus und Sperrbildschirmvorschauen. Stummschalten genehmigt, verwirft und beantwortet nichts automatisch. Unterstützt wird ein aktiver lokaler Host mit einem Zustandsverzeichnis. Gemeinsame Verzeichnisse mehrerer Hosts, ältere macOS-Versionen und Intel sind nicht auf echten Geräten geprüft. Vorhandene lokale Abnahmen betreffen Menüausklappen, letzte Sitzungen, Entwurferhalt, Antwortlöschung und Rücknahme nach Antwort/Abbruch in DSH; sie bestätigen keine reale Abnahme jeder Sprache.

## Entwicklung und Prüfung

```sh
npm ci --ignore-scripts
npm test
npm run test:native
npm run check:release
```

Das vollständige Quellarchiv enthält Tests, Lockdateien, CI und Build-Skripte. Das Plugin-`.tgz` enthält Laufzeitcode und Helferquellen, jedoch nicht die ganze Testsuite. Siehe [Release-Ablauf](docs/release.md) und [Änderungen](CHANGELOG.md).

## Lizenz

[MIT](LICENSE). Der DSH-Name und das lokal bezogene offizielle Symbol kennzeichnen die Integration; Rechte an Drittmarken werden nicht eingeräumt. Offline-Ressourcen und Lizenzen stehen in [THIRD_PARTY](THIRD_PARTY.md).
