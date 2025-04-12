from pathlib import Path

import wx
import construct as cs
from construct_editor.wx_widgets import WxConstructHexEditor

from sarugetchu_mm_patcher.chardata_formats import CharFile, CharData

STRUCT_FORMAT = cs.Struct(
    "a" / cs.Int16sb,
    "b" / cs.Int16sb,
)
SAMPLE_BYTES = bytes(
    list([
        # idk_header
        0x12, 0x34, 0x56, 0x78, 0x12, 0x34, 0x56, 0x78,
        # char type
        0x12,
        # char name
        0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F,
        # null term
        0x00,
        # idk_data
        0x12,
        # story loadout
        0x12, 0x34, 0x56, 0x78, 0x9A,
        # idk_data
        0x12, 0x34, 0x56, 0x78, 0x12, 0x34, 0x56, 0x78,
        # vs_loadout
        0x12, 0x34, 0x56, 0x78, 0x9A,
        # idk_data
        0x12, 0x34, 0x56, 0x78, 0x12, 0x34, 0x56, 0x78,
        # equipped costume
        0x03,
    ]
    # Gadgets
    + [
        # gadget name
        0x88, 0xA0, 0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F, 0x88, 0x9F,
        # idk data
        0x00, 0x00,
        # item type idx,
        0x00,
        # slots
        0xFF, 0xFF, 0xFF,
        # default
        0x01,
    ]*101
    # Power up parts
    + [
        0xFF,
    ]*99
    # Chips
    + [
        0x01
    ]*99
    + [
        # idk data
        0x00,
        # Summons
        0xFF, 0xFF, 0xFF,
        # idk data
        0x00,
        # unlocked costumes
        0xFF, 0xFF,
        # idk_data
        0x00, 0x00,
    ]
    # Saru book
    + [0x00]*0x4C
    + [
        # Checksum
        0x00, 0x00,
        # Char status
        0xFF,
        # idk data
        0x00
    ])*32
)

class MyFrame(wx.Frame):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        menu_bar = wx.MenuBar()
        file_menu = wx.Menu()
        open_item = file_menu.Append(wx.ID_OPEN, "Open", "Open file")
        save_item = file_menu.Append(wx.ID_SAVE, "Save", "Save file")
        saveas_item = file_menu.Append(wx.ID_SAVEAS, "Save as", "Save file as new file")
        quit_item = file_menu.Append(wx.ID_EXIT, "Quit", "Quit application")

        menu_bar.Append(file_menu, "&File")
        self.SetMenuBar(menu_bar)

        self.Bind(wx.EVT_MENU, self.on_quit, quit_item)
        self.Bind(wx.EVT_MENU, self.on_open, open_item)

        self.editor_panel = WxConstructHexEditor(
            self, construct=CharData, binary=SAMPLE_BYTES
        )
        self.editor_panel.construct_editor.expand_all()

        self.Center()

    def on_quit(self, _):
        self.Close()

    def on_open(self, _):
        file_dialog: wx.FileDialog
        with wx.FileDialog(
            self,
            "Open chardata file",
            wildcard="chardata",
            style=wx.FD_OPEN | wx.FD_FILE_MUST_EXIST,
        ) as file_dialog:

            if file_dialog.ShowModal() == wx.ID_CANCEL:
                return  # the user changed their mind

            # Proceed loading the file chosen by the user
            pathname = Path(file_dialog.GetPath())
            with open(pathname, "rb") as file:
                self.editor_panel.binary = file.read()
                self.editor_panel.refresh()


def main():

    app = wx.App(False)
    frame = MyFrame(None)
    frame.Show(True)
    app.MainLoop()

if __name__ == "__main__":
    main()