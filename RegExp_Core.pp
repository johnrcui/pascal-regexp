unit RegExp_Core;

{$mode ObjFPC}{$H+}

{$IFOPT D+}
{$DEFINE DEBUG_LOG}
{$ENDIF}

interface
  type
    PLiteralChar = ^LiteralChar;
    LiteralChar = WideChar;
    PLiteralCharGroup = ^LiteralCharGroup;
    LiteralCharGroup = packed Array of LiteralChar;
    TCharsetMode = (cmLiteral, cmRange);
    PCharset = ^TCharset;
    TCharset = record
      case Mode: TCharsetMode of
        cmLiteral: ( Literal: LiteralChar );
        cmRange: (
          StartAt: LiteralChar;
          EndAt: LiteralChar;
        )
    end;
    PCharsetArray = ^TCharsetArray;
    TCharsetArray = Array of TCharset;
    PCharGroup = ^TCharGroup;
    TCharGroup = record
      MinQuantity: Word;
      MaxQuantity: Word;
      Negated: Boolean;
      Charset: TCharsetArray;
    end;
    PCharGroupSequence = ^TCharGroupSequence;
    TCharGroupSequence = packed Array of TCharGroup;
  function ScanLiteral(const Text: PWideChar; const Cursor: LongWord; const AChar: LiteralChar): Boolean;
  function ScanGroup(const Text: PWideChar; const Cursor: LongWord; const Group: PLiteralCharGroup): Boolean;
  function ScanRange(const Text: PWideChar; const Cursor: LongWord; StartAt, EndAt: LiteralChar): Boolean;
  function ScanCharset(const Text: PWideChar; const Cursor: LongWord; const CharSet: TCharset): Boolean;
  function ScanCharGroup(const Text: PWideChar; const Cursor: LongWord; const CharGroup: TCharGroup; out Matches: LongWord): Boolean;
  function ScanSequence(const Text: PWideChar; const Cursor: LongWord; const Sequence: TCharGroupSequence): Boolean;
  function StringToSequence(const AString: PWideChar): TCharGroupSequence;

implementation
  
  uses
    SysUtils;

  function BoolToStr(Value: Boolean): PChar;
  begin
    if Value then
      Result := 'True'
    else
      Result := 'False';
  end;

  {*--------------------------------------------------------------------------*
    Scan for a literal character at the current cursor position in text

    @param Text text to scan
    @param Cursor index position of character to scan
    @param AChar single character to compare
    @returns True if match
  *---------------------------------------------------------------------------*}
  function ScanLiteral(const Text: PWideChar; const Cursor: LongWord; const AChar: LiteralChar): Boolean;
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
  function ScanGroup(const Text: PWideChar; const Cursor: LongWord; const Group: PLiteralCharGroup): Boolean;
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
  function ScanRange(const Text: PWideChar; const Cursor: LongWord; StartAt, EndAt: LiteralChar): Boolean;
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
    @param CharSet one of literal or range of characters
    @returns True if match
  *---------------------------------------------------------------------------*}
  function ScanCharset(const Text: PWideChar; const Cursor: LongWord; const CharSet: TCharset): Boolean;
  begin
    case CharSet.Mode of
      cmLiteral:
      begin
        {$IFDEF DEBUG_LOG}
          WriteLn('ScanCharset (cmLiteral)');
        {$ENDIF}
        Result := ScanLiteral(Text, Cursor, CharSet.Literal);
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
    Scan character set group 

    @param Text text to scan
    @param Cursor index position of character to scan
    @param CharGroup one of literal or range of characters
    @exports Matches number of sequential characters matched
    @returns True if match
  *---------------------------------------------------------------------------*}
  function ScanCharGroup(const Text: PWideChar; const Cursor: LongWord; const CharGroup: TCharGroup; out Matches: LongWord): Boolean;
  var
    I: LongWord = 0;
    J: Word;
    Matched: Boolean;
  begin
    {$IFDEF DEBUG_LOG}
    WriteLn(Format('ScanCharGroup: '#10'  Min (%d)'#10'  Max (%d)'#10'  Negated(%s)'#10'  %d item(s)', [
      CharGroup.MinQuantity,
      CharGroup.MaxQuantity,
      BoolToStr(CharGroup.Negated),
      Length(CharGroup.Charset)
    ]));
    {$ENDIF}

    Matches := 0;

    while Text[Cursor + I] <> #0 do
    begin
      // § Not at the end of string

      if (
        (CharGroup.MaxQuantity > 0) and
        (Matches >= CharGroup.MaxQuantity)
      ) then
        // 
        break;

      // § Find match on any charset
      Matched := False;
      for J := 0 to Length(CharGroup.Charset) - 1 do
      begin
        if ScanCharset(Text, Cursor + I, CharGroup.Charset[J]) then
        begin
          Matched := True;
          break;
        end;
      end;

      // Increment matches for either condition
      // * Negated and not Matched
      // * Not negated and matched
      if CharGroup.Negated <> Matched then
        Inc(Matches)
      else
        break;

      // Increment cursor position
      Inc(I);
    end;

    Result := Matches >= CharGroup.MinQuantity;
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
  function ScanSequence(const Text: PWideChar; const Cursor: LongWord; const Sequence: TCharGroupSequence): Boolean;
  var
    I: LongWord = 0;
    J: Word = 0;
    M: LongWord = 0;
    C: WideChar;
    P: LongWord;
  begin
    {$IFDEF DEBUG_LOG}
    WriteLn(Format('ScanSequence: %d items', [ Length(Sequence) ]));
    {$ENDIF}

    while Text[Cursor + I] <> #0 do
    begin
      // § Not at the end of string
      C := Text[Cursor + I];

      if J < Length(Sequence) then
      begin
        // § Sequence not complete

        if ScanCharGroup(Text, Cursor + I, Sequence[J], M) then
        begin
          // § Match found
          
          if J = 0 then
            P := I;     // Pin the cusor posiion (for backtracking)

          Inc(J);       // Increment sequence counter
          Inc(I, M);    // Move cursor up by matching result count
        end
        else if J = 0 then
          // § Sequence not yet started, move cursor up
          Inc(I)
        else
        begin
          // § Sequence could not be completed
          {$IFDEF DEBUG_LOG}
          WriteLn(Format('ScanSequence failed at index %d!', [ J ]));
          {$ENDIF}

          // Exit(False);
          // Backtrack to pinned pos + 1
          J := 0;
          I := P + 1;
        end;
      end
      else
        // § Sequence completed
        Exit(True);
    end;

    Result := J = Length(Sequence);
  end;

  {*--------------------------------------------------------------------------*
    Convert a string to a character sequence

    @param AString string to convert
    @returns TCharsetSequence
  *---------------------------------------------------------------------------*}
  function StringToSequence(const AString: PWideChar): TCharGroupSequence;
  var
    I: Integer;
    Groups: Integer = 0;
    Charset: PCharset;
    CharGroup: PCharGroup;
  begin
    {$IFDEF DEBUG_LOG}
    WriteLn(Format('StringToSequence: (%s)', [ AString]));
    {$ENDIF}

    Result := nil;

    for I := 0 to StrLen(AString) - 1 do
    begin
      if (I > 0) and (Result[Groups - 1].Charset[0].Literal = AString[I]) then
      begin
        // dedupe consecutive matching chars
        Inc(Result[Groups - 1].MaxQuantity);
      end
      else
      begin
        SetLength(Result, Groups + 1);

        New(CharGroup);
        New(Charset);

        Charset^.Mode := cmLiteral;
        Charset^.Literal := AString[I];

        CharGroup^.MinQuantity := 1;
        CharGroup^.MaxQuantity := 1;
        CharGroup^.Negated := False;

        SetLength(CharGroup^.Charset, 1);

        CharGroup^.Charset[0] := Charset^;

        Result[Groups] := CharGroup^;

        Dispose(Charset);
        Dispose(CharGroup);

        Inc(Groups);    
      end;
    end;
  end;
end.