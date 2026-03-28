Lazarus PascalScript RuntimeDesigner/Debugger 

Status: 🛠 Alpha – Experimentelle Entwicklung, kann instabil sein

PascalScriptDesigner ist ein plattformunabhängiges IDE für PascalScript, das zwei Welten kombiniert:

Drag-&-Drop Form Designer (basierend auf JvDesign)
PascalScript-Konsole mit Debugger (RemObjects PascalScript)

Platformunabhängig (Linux, Windows)

🔑 Key Features
Drag & Drop Form Designer – Komponenten per Maus platzieren.
Automatisches Code-Linking – Doppelklick auf ein Designer-Element springt direkt zur Code-Stelle.
Debugger-Support – Breakpoints, Step Into / Step Over, Variablenüberwachung.
Erweiterte Funktionen durch Modifikationen
PascalScript Debugger: Prüft, ob Code an bestimmter Datei/Zeile vorhanden ist
JvDesignSurface: Doppelklick-Event (OnControlDblClick) für Designer-Komponenten
⚙ Modifizierte Komponenten

Alle Modifikationen befinden sich im Verzeichnis source/components.

PascalScript (Debugger)

Neue Funktion in PascalScript.pas:

function TPSCustomDebugExec.HasCode(Filename: string; LineNo: integer): boolean;
var
  i, j: integer;
  fi: PFunctionInfo;
  pt: TIfList;
  r: PPositionData;
begin
  result := false;
  for i := 0 to FDebugDataForProcs.Count - 1 do
  begin
    fi := FDebugDataForProcs[i];
    pt := fi^.FPositionTable;
    for j := 0 to pt.Count - 1 do
    begin
      r := pt[j];
      result := SameText(r^.FileName, Filename) and (r^.Row = LineNo);
      if result then exit;
    end;
  end;
end;

Quelle: StackOverflow: Making an IDE using PascalScript and SynEdit

Modifikationen in JvDesignSurface.pas:

type
  TJvDesignControlEvent = procedure(Sender: TObject; AControl: TControl) of object;

  TJvDesignSurface = class(TComponent)
  private
    FOnControlDblClick: TJvDesignControlEvent;
  published
    property OnControlDblClick: TJvDesignControlEvent read FOnControlDblClick write FOnControlDblClick;
  end;
  
Doppelklick auf eine Komponente löst OnControlDblClick aus
Änderungen in TJvDesignCustomMessenger.IsDesignMessage ermöglichen korrektes Handling von Design-Nachrichten



⚠ Known Limitations / Bugs
Events werden nur auf 32-Bit-Versionen (Linux & Windows) ausgelöst, da die PascalScript-Portierung in Lazarus aktuell nur 32-Bit unterstützt
Alpha-Status: Das Projekt ist experimentell und kann instabil sein
