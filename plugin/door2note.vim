if exists('g:loaded_door2note_nvim')
  finish
endif

let g:door2note_open_fn = get(g:, 'door2note_open_fn', 'open_normal')

com! Door2NoteOpenNormal lua require('door2note').open_normal()
com! Door2NoteOpenFloat lua require('door2note').open_float()
com! Door2NoteOpen lua require('door2note').open()

let g:loaded_door2note_nvim = 1
