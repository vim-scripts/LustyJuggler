"    Copyright: Copyright (C) 2007 Stephen Bach
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               lusty-juggler.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damages
"               resulting from the use of this software.
"
" Name Of File: lusty-juggler.vim
"  Description: Dynamic Buffer Switcher Vim Plugin
"   Maintainer: Stephen Bach <sjbach@users.sourceforge.net>
"
" Release Date: Monday, October 23, 2007
"      Version: 1.0
"
"        Usage: To launch the juggler:
"
"                 <Leader>lj
"                 or
"                 <Leader>lg
"
"               You can also use this command:
"
"                 ":LustyJuggler"
"
"               (Personally, I map this to ,g)
"
"               When the juggler launches, the command bar at bottom is
"               replaced with a new bar showing the names of your currently
"               opened buffers in most-recently-used order.
"
"               The buffer names are mapped to these keys:
"
"                   1st|2nd|3rd|4th|5th|6th|7th|8th|9th|10th
"                   ----------------------------------------
"                   a   s   d   f   g   h   j   k   l   ;
"                   1   2   3   4   5   6   7   8   9   0
"
"               So if you type "f" or "4", the fourth buffer name will be
"               highlighted and the bar will shift to center it as necessary
"               (and show more of the buffer names on the right).
"
"               If you want to switch to that buffer, press "f" or "4" again
"               or press "<ENTER>".  Alternatively, press one of the other
"               mapped keys to highlight another buffer.
"
"               To cancel the juggler, press any of "q", "<ESC>", "<C-c",
"               "<BS>", "<Del>", or "<C-h>".
"
" Install Details:
" Copy this file into your $HOME/.vim/plugin directory so that it will be
" sourced on startup automatically.
"
" Note! This plugin requires Vim be compiled with Ruby interpretation.  If you
" don't know if your build of Vim has this functionality, you can check by
" running "vim --version" from the command line and looking for "+ruby".
" Alternatively, just try sourcing this script.
"
" If your version of Vim does not have "+ruby" but you would still like to
" use this plugin, you can fix it.  See the "Check for Ruby functionality"
" comment below for instructions.
"
" If you are using the same Vim configuration and plugins for multiple
" machines, some of which have Ruby and some of which don't, you may want to
" turn off the "Sorry, LustyJuggler requires ruby" warning.  You can do so
" like this (in .vimrc):
"
"   let g:LustyJugglerSuppressRubyWarning = 1
"
" TODO:
" - save and restore mappings
" - fix inconsistent layouts (non-full space usage)
" - Colourize directories/slashes in buffer list.
" - Add TAB recognition back.
" - Add option to open buffer immediately when mapping is pressed (but not
"   release the juggler until the confirmation press).

" Switch very quickly between your 10 most recently used buffers.

" Exit quickly when already loaded.
if exists("g:loaded_lustyjuggler")
  finish
endif

" Check for Ruby functionality.
if !has("ruby")
  if !exists("g:LustyExplorerSuppressRubyWarning") ||
      \ g:LustyExplorerSuppressRubyWarning == "0"
  if !exists("g:LustyJugglerSuppressRubyWarning") ||
      \ g:LustyJugglerSuppressRubyWarning == "0" 
    echohl ErrorMsg
    echon "Sorry, LustyJuggler requires ruby.  "
    echon "Here are some tips for adding it:\n"

    echo "Debian / Ubuntu:"
    echo "    # apt-get install vim-ruby\n"

    echo "Fedora:"
    echo "    # yum install vim-enhanced\n"

    echo "Gentoo:"
    echo "    # USE=\"ruby\" emerge vim\n"

    echo "FreeBSD:"
    echo "    # pkg_add -r vim+ruby\n"

    echo "Windows:"
    echo "    1. Download and install Ruby from here:"
    echo "       http://www.ruby-lang.org/"
    echo "    2. Install a Vim binary with Ruby support:"
    echo "       http://hasno.info/2007/5/18/windows-vim-7-1-2\n"

    echo "Manually (including Cygwin):"
    echo "    1. Install Ruby."
    echo "    2. Download the Vim source package (say, vim-7.0.tar.bz2)"
    echo "    3. Build and install:"
    echo "         # tar -xvjf vim-7.0.tar.bz2"
    echo "         # ./configure --enable-rubyinterp"
    echo "         # make && make install"
    echohl none
  endif
  endif
  finish
endif

let g:loaded_lustyjuggler = "yep"

" Commands.
if !exists(":LustyJuggler")
  command LustyJuggler :call <SID>LustyJugglerStart()
endif

" Default mappings.
nmap <silent> <Leader>lg :LustyJuggler<CR>
nmap <silent> <Leader>lj :LustyJuggler<CR>

" Vim-to-ruby function calls.
function! s:LustyJugglerStart()
  ruby $lusty_juggler.run
endfunction

function! LustyJugglerKeyPressed(code_arg)
  ruby $lusty_juggler.key_pressed
endfunction

function! LustyJugglerCancel()
  ruby $lusty_juggler.cleanup
endfunction

" Setup the autocommands that handle buffer MRU ordering.
augroup LustyJuggler
  autocmd!
  autocmd BufEnter * ruby $buffer_stack.push
  autocmd BufDelete * ruby $buffer_stack.pop
  autocmd BufWipeout * ruby $buffer_stack.pop
augroup End

ruby << EOF


class LustyJuggler
  private
    @@KEYS = Hash["a" => 1,
                  "s" => 2,
                  "d" => 3,
                  "f" => 4,
                  "g" => 5,
                  "h" => 6,
                  "j" => 7,
                  "k" => 8,
                  "l" => 9,
                  ";" => 10,
                  "1" => 1,
                  "2" => 2,
                  "3" => 3,
                  "4" => 4,
                  "5" => 5,
                  "6" => 6,
                  "7" => 7,
                  "8" => 8,
                  "9" => 9,
                  "0" => 10,
                  #"TAB" => 100,
                  "ENTER" => 100]

  public
    def initialize
      @running = false
      @last_pressed = nil
      @name_bar = NameBar.new
    end

    def run
      return if @running

      if $buffer_stack.length <= 1
        pretty_msg("PreProc", "No other buffers")
        return
      end

      @running = true

      # Need to zero the timeout length or pressing 'g' will hang.
      @ruler = (eva("&ruler") != "0")
      @showcmd = (eva("&showcmd") != "0")
      @timeoutlen = eva "&timeoutlen"
      set 'timeoutlen=0'
      set 'noruler'
      set 'noshowcmd'
      # fixme showmode?

      # Selection keys.
      @@KEYS.keys.each do |c|
        exe "noremap <silent> #{c} :call LustyJugglerKeyPressed('#{c}')<CR>"
      end
      # Can't use '<CR>' as an argument to :call func for some reason.
      exe "noremap <silent> <CR>  :call LustyJugglerKeyPressed('ENTER')<CR>"
      #exe "noremap <silent> <Tab>  :call LustyJugglerKeyPressed('TAB')<CR>"

      # Cancel keys.
      exe "noremap <silent> q     :call LustyJugglerCancel()<CR>"
      exe "noremap <silent> <Esc> :call LustyJugglerCancel()<CR>"
      exe "noremap <silent> <C-c> :call LustyJugglerCancel()<CR>"
      exe "noremap <silent> <BS>  :call LustyJugglerCancel()<CR>"
      exe "noremap <silent> <Del> :call LustyJugglerCancel()<CR>"
      exe "noremap <silent> <C-h> :call LustyJugglerCancel()<CR>"

      print_buffer_list()
    end

    def key_pressed()
      c = eva("a:code_arg")
      i = @@KEYS[c]

      if (c == @last_pressed) or \
         (@last_pressed and i == 100)
        choose(i)
        cleanup()
        return
      end

      print_buffer_list(i)

      @last_pressed = c
    end

    # Restore settings, mostly.
    def cleanup
      @last_pressed = nil

      set "timeoutlen=#{@timeoutlen}"
      set "ruler" if @ruler
      set "showcmd" if @showcmd

      @@KEYS.keys.each do |c|
        exe "unmap <silent> #{c}"
      end
      exe "unmap <silent> <CR>"
      #exe "unmap <silent> <Tab>"

      exe "unmap <silent> q"
      exe "unmap <silent> <Esc>"
      exe "unmap <silent> <C-c>"
      exe "unmap <silent> <BS>"
      exe "unmap <silent> <Del>"
      exe "unmap <silent> <C-h>"

      @running = false
      msg ""
    end

  private
    def print_buffer_list(active=nil)
      @name_bar.active = active
      @name_bar.print
    end

    def choose(i)
      buf = $buffer_stack.num_at_pos(i)
      exe "b #{buf}"
    end
end

# An item (delimiter/separator or buffer name) on the NameBar.
class BarItem
  def initialize(str, color)
    @str = str
    @color = color
  end

  attr_reader :str, :color

  def length
    @str.length
  end

  def [](*rest)
    return BarItem.new(@str[*rest], @color)
  end

  def BarItem.full_length(array)
    if array
      array.inject(0) { |sum, el| sum + el.length }
    else
      0
    end
  end
end


# A one-line display of the open buffers, appearing in the command display.
class NameBar
  public
    def initialize
      @active = nil
    end

    def active=(i)
      @active = (i ? i - 1 : nil)
    end

    def print
      items = create_items()
      clipped = clip(items)
      NameBar.do_pretty_print(clipped)
    end

  private
    @@BUFFER_COLOR = "PreProc"
    @@ACTIVE_COLOR = "Question"
    @@DELIMITER_COLOR = "None"

    @@SEPARATOR = BarItem.new("|", @@DELIMITER_COLOR)
    @@LEFT_CONT = BarItem.new("<", @@DELIMITER_COLOR)
    @@RIGHT_CONT = BarItem.new(">", @@DELIMITER_COLOR)

    def create_items
      names = $buffer_stack.names

      # If the user pressed a key higher than the number of open buffers,
      # highlight the highest (see also BufferStack.num_at_pos()).
      if @active
        @active = [@active, (names.length - 1)].min
      end

      items = names.inject(Array.new) { |array, name|
        color = (@active and name == names[@active]) ? @@ACTIVE_COLOR \
                                                     : @@BUFFER_COLOR
        array << BarItem.new(name, color)
        array << @@SEPARATOR
      }
      items.pop   # Remove last separator.

      # Account for the separators.
      if @active
        @active = [@active * 2, (items.length - 1)].min
      end

      return items
    end

    # Clip the given array of items to the available display width.
    def clip(items)
      @active = 0 if @active.nil?

      half_displayable_len = columns() / 2

      # The active buffer is excluded since it's basically split between
      # the sides.
      left_len = BarItem.full_length items[0, @active - 1]
      right_len = BarItem.full_length items[@active + 1, items.length - 1]

      right_justify = (left_len > half_displayable_len) and \
                      (right_len < half_displayable_len)

      if right_justify
        # Right justify the bar.
        first_layout = self.method :layout_right
        second_layout = self.method :layout_left
      else
        # Left justify (more likely).
        first_layout = self.method :layout_left
        second_layout = self.method :layout_right
      end

      active_str_half_len = (items[@active].length / 2) + \
                            (items[@active].length % 2 == 0 ? 0 : 1)

      allocation = half_displayable_len - active_str_half_len

      first_side, remainder = first_layout.call(items, allocation)

      allocation = half_displayable_len + \
                   active_str_half_len + \
                   remainder

      second_side, remainder = second_layout.call(items, allocation)

      if right_justify
        second_side + first_side
      else
        first_side + second_side
      end
    end

    # Clip the given array of items to the given space, counting downwards.
    def layout_left(items, space)
      trimmed = Array.new

      i = @active - 1
      while i >= 0
        m = items[i]
        if space > m.length
          trimmed << m
          space -= m.length
        elsif space > 0
          trimmed << m[m.length - (space - @@LEFT_CONT.length), \
                       space - @@LEFT_CONT.length]
          trimmed << @@LEFT_CONT
          space = 0
        else
          break
        end
        i -= 1
      end

      return trimmed.reverse, space
    end

    # Clip the given array of items to the given space, counting upwards.
    def layout_right(items, space)
      trimmed = Array.new

      i = @active
      while i < items.length
        m = items[i]
        if space > m.length
          trimmed << m
          space -= m.length
        elsif space > 0
          trimmed << m[0, space - @@RIGHT_CONT.length]
          trimmed << @@RIGHT_CONT
          space = 0
        else
          break
        end
        i += 1
      end

      return trimmed, space
    end

    def NameBar.do_pretty_print(items)
      args = items.inject(Array.new) { |array, e|
        array << e.color
        array << e.str
      }

      pretty_msg *args
    end
end


# Maintain MRU ordering.
# A little bit different than the LustyExplorer version -- probably they
# should be unified.
class BufferStack
  public
    def initialize
      @stack = Array.new

      (0..VIM::Buffer.count-1).each do |i|
        @stack << VIM::Buffer[i].number
      end
    end

    def names
      cull!
      @stack.collect { |i| buf_name(i) }.reverse[0,10]
    end

    def num_at_pos(i)
      cull!
      return @stack[-i] ? @stack[-i] : @stack.first
    end

    def length
      cull!
      return @stack.length
    end

    def push
      @stack.delete $curbuf.number
      @stack << $curbuf.number
    end

    def pop
      number = eva 'bufnr(expand("<afile>"))'
      @stack.delete number
    end

  private
    def cull!
      # Remove empty buffers.
      @stack.delete_if { |x| eva("bufexists(#{x})") == "0" }
    end

    def buf_name(i)
      eva("bufname(#{i})")
    end
end


# Simple mappings to decrease typing.
def exe(s)
  VIM.command s
end

def eva(s)
  VIM.evaluate s
end

def set(s)
  VIM.set_option s
end

def msg(s)
  VIM.message s
end

def columns
  # Vim gives the annoying "Press ENTER to continue" message if we use the
  # full width.
  eva("&columns").to_i - 1
end

def pretty_msg(*rest)
  return if rest.length == 0
  return if rest.length % 2 != 0

  #exe "redraw"

  i = 0
  while i < rest.length do
    exe "echohl #{rest[i]}"
    exe "echon '#{rest[i+1]}'"
    i += 2
  end

  exe 'echohl None'
end


$lusty_juggler = LustyJuggler.new
$buffer_stack = BufferStack.new


EOF

