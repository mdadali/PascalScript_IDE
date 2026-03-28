unit uCodeGenerator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, SynEdit,
  JvDesignSurface, JvDesignUtils;

function GetControlClass(AControl: TControl): TClass;
procedure GenerateCodeFromDesigner(AJvDesignPanel: TJvDesignPanel; AStringList: TStringList; AFormName: string);
function GetDefaultEventName(Ctrl: TControl): string;
function GetEventHandlerName(Ctrl: TControl): string;
procedure JumpToEventInEditor(Editor: TSynEdit; const EventName: string);
function EventExists(Lines: TStrings; const EventName: string): Boolean;


implementation

// -----------------------------
// Hilfsfunktionen
// -----------------------------
function GetControlClass(AControl: TControl): TClass;
begin
  if AControl is TButton then Exit(TButton);
  if AControl is TEdit then Exit(TEdit);
  if AControl is TMemo then Exit(TMemo);
  if AControl is TPanel then Exit(TPanel);
  if AControl is TLabel then Exit(TLabel);
  if AControl is TCheckBox then Exit(TCheckBox);
  if AControl is TRadioButton then Exit(TRadioButton);
  // andere Controls ergänzen
  Result := AControl.ClassType;
end;

function GetControlClassName(AControl: TControl): string;
begin
  Result := GetControlClass(AControl).ClassName;
end;
function Escape(const s: string): string;
begin
  Result := StringReplace(s, '''', '''''', [rfReplaceAll]);
end;

function GetDefaultEventName(Ctrl: TControl): string;
begin
  if Ctrl is TButton then Exit('OnClick');
  if Ctrl is TEdit then Exit('OnChange');
  if Ctrl is TMemo then Exit('OnChange');
  if Ctrl is TCheckBox then Exit('OnClick');
  if Ctrl is TRadioButton then Exit('OnClick');

  Result := '';
end;

function GetEventHandlerName(Ctrl: TControl): string;
begin
  Result := Ctrl.Name + '_' + GetDefaultEventName(Ctrl);
end;

procedure JumpToEventInEditor(Editor: TSynEdit; const EventName: string);
var
  i, j: Integer;
  Line: string;
begin
  for i := 0 to Editor.Lines.Count - 1 do
  begin
    Line := Editor.Lines[i];

    if Pos('procedure ' + EventName, Line) > 0 then
    begin
      // Suche das "begin" ab der nächsten Zeile
      for j := i + 1 to Editor.Lines.Count - 1 do
      begin
        if Trim(Editor.Lines[j]) = 'begin' then
        begin
          Editor.CaretY := j + 1;
          Editor.CaretX := 3; // eingerückt
          Editor.SetFocus;
          Exit;
        end;
      end;
    end;
  end;
end;

function EventExists(Lines: TStrings; const EventName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Lines.Count - 1 do
    if Pos('procedure ' + EventName, Lines[i]) > 0 then
      Exit(True);
end;

function ExtractBlock(const SL: TStringList; const StartTag, EndTag: string): TStringList;
var
  i: Integer;
  InBlock: Boolean;
begin
  Result := TStringList.Create;
  InBlock := False;
  for i := 0 to SL.Count - 1 do
  begin
    if Pos(StartTag, SL[i]) > 0 then
    begin
      InBlock := True;
      Continue;
    end;
    if Pos(EndTag, SL[i]) > 0 then
      Break;
    if InBlock then
      Result.Add(SL[i]);
  end;
end;

function HasEvent(const SL: TStringList; const EventName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to SL.Count - 1 do
    if Pos('procedure ' + EventName, SL[i]) > 0 then
      Exit(True);
end;

// -----------------------------
// Komponenten Eigenschaften hinzufügen
// -----------------------------
procedure AddProps(Ctrl: TControl; SL: TStringList);
begin
  SL.Add('  ' + Ctrl.Name + '.Left := ' + IntToStr(Ctrl.Left) + ';');
  SL.Add('  ' + Ctrl.Name + '.Top := ' + IntToStr(Ctrl.Top) + ';');
  SL.Add('  ' + Ctrl.Name + '.Width := ' + IntToStr(Ctrl.Width) + ';');
  SL.Add('  ' + Ctrl.Name + '.Height := ' + IntToStr(Ctrl.Height) + ';');

  if Ctrl is TButton then
    SL.Add('  ' + Ctrl.Name + '.Caption := ''' + Escape(TButton(Ctrl).Caption) + ''';');
  if Ctrl is TLabel then
    SL.Add('  ' + Ctrl.Name + '.Caption := ''' + Escape(TLabel(Ctrl).Caption) + ''';');
  if Ctrl is TEdit then
    SL.Add('  ' + Ctrl.Name + '.Text := ''' + Escape(TEdit(Ctrl).Text) + ''';');
end;

// -----------------------------
// Hauptprozedur
// -----------------------------
procedure GenerateCodeFromDesigner(AJvDesignPanel: TJvDesignPanel; AStringList: TStringList; AFormName: string);
var
  i: Integer;
  Ctrl: TControl;
  UserCode, MainCode, UserGlobalVars, UserProps: TStringList;

  procedure Add(const S: string);
  begin
    AStringList.Add(S);
  end;

begin
  // 1. Alte Blöcke sichern
  UserCode := ExtractBlock(AStringList, '//<USERCODE-BEGIN>', '//<USERCODE-END>');
  MainCode := ExtractBlock(AStringList, '//<MAIN-BEGIN>', '//<MAIN-END>');
  UserGlobalVars := ExtractBlock(AStringList, '//<USER-GLOBAL-VARS-BEGIN>', '//<USER-GLOBAL-VARS-END>');
  UserProps := ExtractBlock(AStringList, '//<USER-PROPS-BEGIN>', '//<USER-PROPS-END>');

  try
    AStringList.Clear;

    // =====================================================
    // DESIGNER VARS
    // =====================================================
    Add('//<DESIGNER-VARS-BEGIN>');
    Add('var');
    Add('  ' + AFormName + ': TForm;');
    for i := 0 to AJvDesignPanel.ComponentCount - 1 do
    begin
      if not (AJvDesignPanel.Components[i] is TControl) then Continue;
      Ctrl := TControl(AJvDesignPanel.Components[i]);
      Add('  ' + Ctrl.Name + ': ' + Ctrl.ClassName + ';');
    end;
    Add('//<DESIGNER-VARS-END>');
    Add('');

    // =====================================================
    // USER-GLOBAL-VARS
    // =====================================================
    Add('//<USER-GLOBAL-VARS-BEGIN>');
    AStringList.AddStrings(UserGlobalVars);
    Add('//<USER-GLOBAL-VARS-END>');
    Add('');

    // =====================================================
    // USER-CODE
    // =====================================================
    Add('//<USERCODE-BEGIN>');
    AStringList.AddStrings(UserCode);
    // Events automatisch ergänzen (TButton.OnClick, TEdit.OnChange)
    for i := 0 to AJvDesignPanel.ComponentCount - 1 do
    begin
      if not (AJvDesignPanel.Components[i] is TControl) then Continue;
      Ctrl := TControl(AJvDesignPanel.Components[i]);

      if Ctrl is TButton then
        if not HasEvent(UserCode, Ctrl.Name + '_OnClick') then
        begin
          Add('procedure ' + Ctrl.Name + '_OnClick(Sender: TObject);');
          Add('begin');
          Add('  ');
          Add('end;');
          Add('');
        end;

      if Ctrl is TEdit then
        if not HasEvent(UserCode, Ctrl.Name + '_OnChange') then
        begin
          Add('procedure ' + Ctrl.Name + '_OnChange(Sender: TObject);');
          Add('begin');
          Add('  ');
          Add('end;');
          Add('');
        end;
    end;
    Add('//<USERCODE-END>');
    Add('');

    // =====================================================
    // DESIGNER + USER-PROPS + Visible fix
    // =====================================================
    Add('//<DESIGNER-BEGIN>');
    Add('procedure CreateNewForm;');
    Add('begin');
    Add('  ' + AFormName + ' := TForm.Create(nil);');
    Add('  ' + AFormName + '.Caption := ''' + Escape(AFormName) + ''';');
    Add('  ' + AFormName + '.Position := poDesigned;');
    Add('');

    // Komponenten erzeugen + Events
    for i := 0 to AJvDesignPanel.ComponentCount - 1 do
    begin
      if not (AJvDesignPanel.Components[i] is TControl) then Continue;
      Ctrl := TControl(AJvDesignPanel.Components[i]);

      Add('  ' + Ctrl.Name + ' := ' + Ctrl.ClassName + '.Create(' + AFormName + ');');
      Add('  ' + Ctrl.Name + '.Parent := ' + AFormName + ';');

      if Ctrl is TButton then
        Add('  ' + Ctrl.Name + '.OnClick := @' + Ctrl.Name + '_OnClick;');
      if Ctrl is TEdit then
        Add('  ' + Ctrl.Name + '.OnChange := @' + Ctrl.Name + '_OnChange;');

      Add('');
    end;

    // USER-PROPS
    Add('  //<USER-PROPS-BEGIN>');
    if UserProps.Count > 0 then
      AStringList.AddStrings(UserProps)
    else
      for i := 0 to AJvDesignPanel.ComponentCount - 1 do
      begin
        if not (AJvDesignPanel.Components[i] is TControl) then Continue;
        Ctrl := TControl(AJvDesignPanel.Components[i]);
        AddProps(Ctrl, AStringList);
      end;
    Add('  //<USER-PROPS-END>');

    // Form sichtbar machen **nach User-Props**
    Add('  ' + AFormName + '.Visible := True;');

    Add('end;');
    Add('//<DESIGNER-END>');
    Add('');

    // =====================================================
    // MAIN-BLOCK
    // =====================================================
    Add('//<MAIN-BEGIN>');
    if MainCode.Count > 0 then
      AStringList.AddStrings(MainCode)
    else
    begin
      Add('begin');
      Add('  CreateNewForm;');
      Add('end.');
    end;
    Add('//<MAIN-END>');

  finally
    UserCode.Free;
    MainCode.Free;
    UserGlobalVars.Free;
    UserProps.Free;
  end;
end;

end.
