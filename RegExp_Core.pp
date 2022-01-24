unit RegExp_Core;

{$mode ObjFPC}{$H+}

{$IFOPT D+}
// {$DEFINE DEBUG_LOG}
{$ENDIF}

interface
  type
    PLiteralChar = ^LiteralChar;
    LiteralChar = WideChar;
    PLiteralCharGroup = ^LiteralCharGroup;
    LiteralCharGroup = packed Array of LiteralChar;
    TCharsetMode = (cmLiteral, cmLiteralGroup, cmRange);
    PCharset = ^TCharset;
    TCharset = record
      case Mode: TCharsetMode of
        cmLiteral: ( Literal: LiteralChar );
        cmLiteralGroup: ( Group: PLiteralCharGroup );
        cmRange: (
          StartAt: LiteralChar;
          EndAt: LiteralChar;
        )
    end;
    PCharsetSequence = ^TCharsetSequence;
    TCharsetSequence = packed Array of TCharset;
  function ScanLiteral(const Text: PWideChar; const Cursor: Integer; const AChar: LiteralChar): Boolean;
  function ScanGroup(const Text: PWideChar; const Cursor: Integer; const Group: PLiteralCharGroup): Boolean;
  function ScanRange(const Text: PWideChar; const Cursor: Integer; StartAt, EndAt: LiteralChar): Boolean;
  function ScanSequence(const Text: PWideChar; const Cursor: Integer; const Sequence: TCharsetSequence): Boolean;
  function StringToSequence(const AString: PWideChar): TCharsetSequence;

implementation
  
  uses
    SysUtils;

  {*--------------------------------------------------------------------------*
    Scan for a literal character at the current cursor position in text

    @param Text text to scan
    @param Cursor index position of character to scan
    @param AChar single character to compare
    @returns True if match
  *---------------------------------------------------------------------------*}
  function ScanLiteral(const Text: PWideChar; const Cursor: Integer; const AChar: LiteralChar): Boolean;
  begin
    {$IFDEF DEBUG_LOG}
    WriteLn(Format('ScanLiteral: #$%4.4x  (%s)', [ Word(AChar), AChar ]));
    {$ENDIF}

    Result := Text[Cursor] = AChar;
  end;

  {*--------------------------------------------------------------------------*
    Scan for one of a group of characters at the current cursor position
    in text

    @param Text text to scan
    @param Cursor index position of character to scan
    @param Group group of characters co compare
    @returns True if any match
  *---------------------------------------------------------------------------*}
  function ScanGroup(const Text: PWideChar; const Cursor: Integer; const Group: PLiteralCharGroup): Boolean;
  var
    I: Integer;
  begin
    {$IFDEF DEBUG_LOG}
    WriteLn('ScanGroup: [');
    for I := 0 to Length(LiteralCharGroup(Group)) do
    begin
      WriteLn(Format('  #$%4.4x  (%s)', [
        Word(LiteralCharGroup(Group)[I]),
        LiteralCharGroup(Group)[I]
      ]));
    end;
    WriteLn(']');
    {$ENDIF}

    Result := False;

    for I := 0 to Length(LiteralCharGroup(Group)) do
    begin
      if Text[Cursor] = LiteralCharGroup(Group)[I] then
      begin
        Result := True;
        break;
      end;  
    end;
  end;

  {*--------------------------------------------------------------------------*
    Scan for a range of characters at the current cursor position in text

    @param Text text to scan
    @param Cursor index position of character to scan
    @param StartAt starting character in range (inclusive)
    @param EndAt ending character in range (inclusive)
    @returns True if match
  *---------------------------------------------------------------------------*}
  function ScanRange(const Text: PWideChar; const Cursor: Integer; StartAt, EndAt: LiteralChar): Boolean;
  begin
    {$IFDEF DEBUG_LOG}
    WriteLn(Format('ScanRange: #$%4.4x  (%s)- #$%4.4x  (%s)', [
      Word(StartAt),
      StartAt,
      Word(EndAt),
      EndAt
    ]));
    {$ENDIF}

    Result := (Text[Cursor] >= StartAt) and (Text[Cursor] <= EndAt);
  end;

  {*--------------------------------------------------------------------------*
    Perform a selective scan of characters at the current cursor position
    in text based on the type of character set

    @param Text text to scan
    @param Cursor index position of character to scan
    @param CharSet one of literal, group, or range of characters
    @returns True if match
  *---------------------------------------------------------------------------*}
  function ScanCharset(const Text: PWideChar; const Cursor: Integer; CharSet: TCharset): Boolean;
  begin
    case CharSet.Mode of
      cmLiteral:
      begin
        {$IFDEF DEBUG_LOG}
          WriteLn('ScanCharset (cmLiteral)');
        {$ENDIF}
        Result := ScanLiteral(Text, Cursor, CharSet.Literal);
      end;
      cmLiteralGroup:
      begin
        {$IFDEF DEBUG_LOG}
          WriteLn('ScanCharset (cmLiteralGroup)');
        {$ENDIF}
        Result := ScanGroup(Text, Cursor, CharSet.Group);
      end;
      cmRange:
      begin
        {$IFDEF DEBUG_LOG}
          WriteLn('ScanCharset (cmRange)');
        {$ENDIF}
        Result := ScanRange(Text, Cursor, CharSet.StartAt, CharSet.EndAt);
      end;
    end;
  end;

  {*--------------------------------------------------------------------------*
    Scan a sequence of characters to compare starting at the current cursor
    position in the text up to the cursor + n, where n is the length of
    the character sequence

    @param Text text to scan
    @param Cursor starting position of characters to scan
    @param Sequence sequence of characters to compare
    @returns True if match
  *---------------------------------------------------------------------------*}
  function ScanSequence(const Text: PWideChar; const Cursor: Integer; const Sequence: TCharsetSequence): Boolean;
  var
    I: Integer = 0;
    C: WideChar;
  begin
    {$IFDEF DEBUG_LOG}
    WriteLn(Format('ScanSequence: %d items', [ Length(Sequence)]));
    {$ENDIF}
    Result := True;

    for I := 0 to Length(Sequence) - 1 do
    begin
      if not ScanCharset(Text, Cursor + I, Sequence[I]) then
      begin
        {$IFDEF DEBUG_LOG}
        WriteLn(Format('ScanSequence failed at index %d!', [ I ]));
        {$ENDIF}

        Result := False;
        break;
      end;
    end;
  end;

  {*--------------------------------------------------------------------------*
    Convert a string to a character sequence

    @param AString string to convert
    @returns TCharsetSequence
  *---------------------------------------------------------------------------*}
  function StringToSequence(const AString: PWideChar): TCharsetSequence;
  var
    I: Integer;
    Charset: PCharset;
  begin
    {$IFDEF DEBUG_LOG}
    WriteLn(Format('StringToSequence: (%s)', [ AString]));
    {$ENDIF}

    SetLength(Result, StrLen(AString));

    for I := 0 to StrLen(AString) - 1 do
    begin
      New(Charset);

      Charset^.Mode := cmLiteral;
      Charset^.Literal := AString[I];

      Result[I] := Charset^;

      Dispose(Charset);
    end;
  end;
end.