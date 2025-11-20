import os
import osproc
import sequtils
import strutils
import terminal

const
  msg1 = "Put VPN '.config' files in '~/.config/vpn'."
  msg2 = "Use the arrow keys and 'enter' to select a VPN. Press 'q' to quit.\n"
  path = getHomeDir() & "/.config/vpn"


let
  # The output is empty if there is no VPN connected, and an error message otherwise.
  wgout = "wg".execProcess()

  (width, height) = terminalSize()
  
  # Extracts the name of all '.conf' files from the '~/.config/vpn' directory.
  fs = toSeq(walkDir(path))
    .mapIt(it.path.split("/")[^1].split("."))
    .filterIt(it[1] == "conf").mapIt(it[0])


var
  current = 0
  active = if wgout == "": -1 else: fs.find wgout.split(" ")[4][0..^2]


# In the second 'if' block, 'go' gives an error the first time and requires
# the next command. If we don't run the first 'go', the second will still
# give an error even after running 'resolvconf'.
proc toggleVPN() =
  proc go() = discard ("wg-quick up " & path & "/" & fs[current] & ".conf").execProcess()
  
  if active != -1:
    discard ("wg-quick down " & path & "/" & fs[active] & ".conf").execProcess()
  
  if current == active: active = -1
  else:
    go()
    discard "sudo resolvconf -u".execProcess()
    go()
    active = current


proc handleArrows() =
  if getch() != '[': return # The next character marks the arrow pressed.

  case getch()
  of 'A': # Up arrow
    if current == 0: current = fs.len - 1
    else: dec current
  of 'B': # Down arrow
    if current == fs.len - 1: current = 0
    else: inc current
  else: discard


proc printScreen() =
  eraseScreen()
  # Print centred instructions.
  setCursorPos width div 2 - msg1.len div 2, (height div 2 - fs.len div 2 - 3)
  echo msg1
  setCursorXPos width div 2 - msg2.len div 2
  echo msg2

  # Print styled config file names.
  for i, f in fs:
    setCursorXPos width div 2 - f.len div 2
    if current != i and active == i: styledEcho fgGreen, f, fgDefault
    elif current == i and active != i: styledEcho styleUnderscore, f
    elif current == i and active == i: styledEcho fgGreen, styleUnderscore, f, fgDefault
    else: echo f

  echo ""
  # Show an indicator of what pressing 'enter' will do.
  if current == active:
    setCursorXPos width div 2 - 5
    styledEcho fgRed, styleBright, "Disconnect", fgDefault
  else:
    setCursorXPos width div 2 - 3
    styledEcho fgGreen, styleBright, "Connect", fgDefault


proc exit() =
  eraseScreen()
  setCursorPos 0, 0
  quit()


###############################################################################
#                                                                             #
#                                      Main                                   #
#                                                                             #
###############################################################################

echo "Sudo permissions are needed to manage VPNs!"
discard "sudo -l".execProcess() # Will obtain sudo permissions if needed.
hideCursor()

while true:
  printScreen()

  case getch() # Handle input.
  of 'q': exit()
  of '\x1b': handleArrows() # '\x1b' marks the start of an escape sequence.
  of '\n', '\r': toggleVPN() # Connect/disconnect on pressing 'enter'.
  else: discard

