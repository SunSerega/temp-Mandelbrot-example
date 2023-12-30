unit ExecInfo;

{$savepcu false}

{$reference System.Windows.Forms.dll}
{$reference System.Drawing.dll}
uses System.Windows.Forms;
uses System.Drawing;

uses Settings;

type
  
  TextBlock = sealed class(&Label)
    protected procedure OnPaint(e: System.Windows.Forms.PaintEventArgs); override;
    begin
      self.MinimumSize := e.Graphics.MeasureString(Text, Font).ToSize;
//      $'[{Text}]: {self.MinimumSize} / {e.ClipRectangle}'.Println;
      var x := 0;
      case self.TextAlign of
        ContentAlignment.MiddleLeft: ;
        ContentAlignment.MiddleRight: x := (e.ClipRectangle.Width-self.MinimumSize.Width).ClampBottom(0);
        else raise new System.NotSupportedException(self.TextAlign.ToString);
      end;
      var y := ((e.ClipRectangle.Height-self.MinimumSize.Height) div 2).ClampBottom(0);
      e.Graphics.DrawString(Text, Font, new SolidBrush(ForeColor), x, y);
    end;
  end;
  
  InfoWindow = sealed class(Form)
    
    private tlp := new TableLayoutPanel;
    
    private row_count := 0;
    private function DefineRow: (integer,TextBlock,TextBlock,TextBlock);
    begin
      var y := tlp.RowStyles.Count;
      tlp.RowStyles.Add(new RowStyle(SizeType.Absolute,0));
      
      var l0 := new TextBlock;
      tlp.Controls.Add(l0, 0, y);
      l0.TextAlign := ContentAlignment.MiddleRight;
      l0.Dock := DockStyle.Right;
      l0.Visible := false;
      
      var l1 := new TextBlock;
      tlp.Controls.Add(l1, 1, y);
      l1.TextAlign := ContentAlignment.MiddleLeft;
      l1.Dock := DockStyle.Left;
      l1.Visible := false;
      
      var l2 := new TextBlock;
      tlp.Controls.Add(l2, 2, y);
      l2.TextAlign := ContentAlignment.MiddleRight;
      l2.Dock := DockStyle.Right;
      l2.Visible := false;
      
      Result := (y,l0,l1,l2);
    end;
    private row_vram := DefineRow();
    private row_ram := DefineRow();
    private row_drive := DefineRow();
    private row_sheet := DefineRow();
    private row_steps := DefineRow();
    private row_ups := DefineRow();
    
    private static main_form: Form;
    public static procedure Init(main_form: Form) :=
      InfoWindow.main_form := main_form;
    
    private static instance := default(InfoWindow);
    private constructor;
    begin
      
      self.StartPosition := FormStartPosition.Manual;
      self.Location := Point.Empty;
      self.FormBorderStyle := System.Windows.Forms.FormBorderStyle.Fixed3D;
      self.Text := 'Scene info';
      
      self.KeyUp += (o,e)->
      case e.KeyCode of
        Keys.Escape:
        begin
          instance := nil;
          self.Close;
        end;
      end;
      
      self.Controls.Add(tlp);
      tlp.ColumnCount := 3;
      tlp.Dock := DockStyle.Fill;
      tlp.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
      tlp.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
      tlp.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
      
      row_vram.Item2.Text := 'VRAM:';
      row_ram.Item2.Text := 'RAM:';
      row_drive.Item2.Text := 'Drive:';
      row_sheet.Item2.Text := 'Sheet:';
      row_steps.Item2.Text := 'Steps:';
      row_ups.Item2.Text := 'Updates:';
      
      if instance<>nil then raise new System.InvalidOperationException;
      instance := self;
    end;
    public static procedure Activate :=
      if instance=nil then
        InfoWindow.Create.Show(main_form) else
        instance.Focus;
    
    private static procedure Update(p: InfoWindow->());
    begin
      if instance=nil then exit;
      main_form.BeginInvoke(()->
      try
        var w := instance;
        if w=nil then exit;
        p(w);
        w.ClientSize := w.tlp.GetPreferredSize(System.Drawing.Size.Empty);
//        w.ClientSize := new System.Drawing.Size(600, 500);
      except
        on e: Exception do
          MessageBox.Show(e.ToString);
      end);
    end;
    
    private procedure SetRowEnabled(enabled: boolean; ind: integer);
    begin
      if enabled then
        tlp.RowStyles[ind] := new RowStyle(SizeType.AutoSize) else
        tlp.RowStyles[ind] := new RowStyle(SizeType.Absolute,0);
      for var x := 0 to tlp.ColumnCount-1 do
        tlp.GetControlFromPosition(x,ind).Visible := enabled;
    end;
    
    private static mem_byte_scales := |'B','KB','MB','GB'|;
    private static function MemUseScale(use: real) := integer(LogN(1024, use)).Clamp(0,mem_byte_scales.Length-1);
    private static function MemUseToString(use: real): string;
    begin
      var scale := MemUseScale(use);
      use /= 1024**scale;
      Result := $'{use:N} {mem_byte_scales[scale]}';
    end;
    private static function MemUseToString(use, total: real): string;
    begin
      var scale := MemUseScale(Max(use,total));
      use /= 1024**scale;
      total /= 1024**scale;
      Result := $'{use:N} / {total:N} {mem_byte_scales[scale]} ({use/total:00.0%})';
    end;
    
    public static procedure UpdateVRAM(blocks, active_blocks, req_blocks: integer; mem_use: int64) := Update(w->
    begin
      var (ind, l_header, l_left, l_right) := w.row_vram;
      w.SetRowEnabled((mem_use<>0) and (Settings.max_VRAM<>0), ind);
      l_left.Text := $'{blocks} blocks ({active_blocks}/{req_blocks} active)';
      l_right.Text := MemUseToString(mem_use, Settings.max_VRAM);
    end);
    
    public static procedure UpdateRAM(blocks: integer; mem_use: int64) := Update(w->
    begin
      var (ind, l_header, l_left, l_right) := w.row_ram;
      w.SetRowEnabled((mem_use<>0) and (Settings.max_RAM<>0), ind);
      l_left.Text := $'{blocks} blocks';
      l_right.Text := MemUseToString(mem_use, Settings.max_RAM);
    end);
    
    public static procedure UpdateDrive(blocks: integer; mem_use: int64) := Update(w->
    begin
      var (ind, l_header, l_left, l_right) := w.row_drive;
      w.SetRowEnabled((mem_use<>0) and (Settings.max_drive_space<>0), ind);
      l_left.Text := $'{blocks} blocks';
      l_right.Text := MemUseToString(mem_use, Settings.max_drive_space);
    end);
    
    public static procedure UpdateSheet(draw_bytes: int64; back_bytes: int64?; draw_req_points: int64) := Update(w->
    begin
      var (ind, l_header, l_left, l_right) := w.row_sheet;
      w.SetRowEnabled(true, ind);
      l_left.Text := MemUseToString(draw_bytes);
      if back_bytes<>nil then
        l_left.Text += $' + {MemUseToString(back_bytes.Value)}';
      l_right.Text := '~'+MemUseToString(draw_req_points*2 * sizeof(cardinal), draw_bytes + back_bytes.GetValueOrDefault);
    end);
    
    public static procedure UpdateSteps(steps, words: integer) := Update(w->
    begin
      var (ind, l_header, l_left, l_right) := w.row_steps;
      w.SetRowEnabled(true, ind);
      l_left.Text := $'{steps}/{Settings.max_steps_at_once} ({steps/Settings.max_steps_at_once:000.0%})';
      l_right.Text := $'{words} words | {words*4} bytes | {words*32} bits';
    end);
    
    public static procedure UpdateUPS(ups, seconds: real) := Update(w->
    begin
      var (ind, l_header, l_left, l_right) := w.row_ups;
      w.SetRowEnabled(true, ind);
      l_left.Text := $'{ups:N1}/step';
      l_right.Text := $'{seconds:N3} ({seconds/Settings.target_step_time_seconds:000.0%})';
    end);
    
  end;
  
end.