---
title: A DSL for writing Applescripts in Emacs Lisp
description: Automate your Mac right from Emacs!
summary: Automate your Mac from Emacs with Lisp macros
date: 2019-06-27T11:30:03+00:00
---

As much as I love Emacs, there's one thing that I've never been
satisfied with: terminal support. There are multiple offerings built
into Emacs, such as
[term-mode](https://www.gnu.org/software/emacs/manual/html_node/emacs/Term-Mode.html)
and the more Emacs-y
[eshell](https://www.masteringemacs.org/article/complete-guide-mastering-eshell). `eshell`
in particular has some great features like being able to use Emacs
Lisp to write shell commands and being able to pipe to Emacs
buffers. However, as a web developer in 2019, much of my terminal use
involves running complicated CLI tools such as
[Jest](https://jestjs.io/) and
[Storybook](https://storybook.js.org/). `eshell` doesn't work at all
with these, and `term-mode` is *significantly* slower than a native
shell.

For a long time, I've just been tabbing over to
[iTerm](https://www.iterm2.com/) for managing these tasks. This
*works*, but it's frustrating having to do undergo such a big context
shift whenever switching to my terminal. Luckily, `iTerm` has great
[Applescript
support](https://www.iterm2.com/documentation-scripting.html) which
allows for easily automating things like creating windows and running
programs.

### Applescript in Emacs

Emacs has a built in function `do-applescript` which takes a string
containing an Applescript and executes it. This is great until you
actually start writing Applescript. To make a long story short: it's
very bad. Plus, writing long strings everywhere is less than
optimal. This opportunity presented a perfect opportunity to mess
around with using Lisp macros to write a simple DSL.

Here's what Applescript looks like:

```applescript
tell application "iTerm"
  tell current window
    create tab with default profile
  end tell
end tell
```

We can then use this script to open a new tab right from Emacs!

```emacs-lisp
(defun iterm-new-tab ()
  (interactive)
  (do-applescript "
tell application \"iTerm\"
	tell current window
		create tab with default profile
	end tell
end tell"))
```

This works, but man is it ugly. The indentation is a pain to deal with
in a string literal, and the `end tell`s just seem redundant. Wouldn't
it be great if we could express this program in a Lisp form? How about this:


```emacs-lisp
(defun iterm-new-tab ()
  (interactive)
  (applescript-do
    (:tell
	  "application \"iTerm\""
	  (:tell "current window" "create tab with default profile"))))
```

Since we'll be writing a bunch of `iTerm` commands, it would even be better to be able to condense it to something like

```emacs-lisp
(defun iterm-new-tab ()
  (interactive)
  (iterm (:tell "current window" "create tab with default profile")))
```

Much better. And it turns out, it only takes a few macros and some
recursion to implement!

### Embracing the magic

First, let's define the `applescript-do` macro which will be the user-facing API.

```emacs-lisp
(defmacro applescript-do (form)
  `(with-temp-buffer
     (applescript--eval-form (quote ,form))
     (do-applescript (buffer-string))))
```

This sends an unevaluated version of the form passed to
`applescript--eval-form`, which will be a recursive function that
parses the form.

```emacs-lisp
(defun applescript--eval-form (form)
  (cond ((eq (car-safe form) :tell)
	 (insert "\ntell ")
	 (insert (eval (cadr form)))
	 (applescript--eval-form (car (last form)))
	 (insert "\nend tell"))
	((stringp form)
	 (insert (concat "\n" form)))
	((listp form) (insert (concat "\n" (eval form))))
	((symbolp form) (insert (concat "\n" (symbol-value form))))
	(t (error "invalid form"))))
```

This function checks the three parts of every form, the `:tell`, the
target, and the command. The command can be another `tell` form, so if
it's a list, send that through the function again. There are some
extra checks to allow for embedding any Emacs Lisp form in the DSL.

Now we can define another simple macro for writing `iTerm` commands,

```emacs-lisp
(defmacro iterm (form)
  `(applescript-do (:tell "application \"iTerm\"" ,form)))
```

And we're done! Now you can write `iTerm` Applescripts in Lisp and
manage your shell from Emacs. For example, run a command using

```emacs-lisp
(defun iterm-run-command (cmd)
  (interactive "MRun command in iTerm: ")
  (iterm (:tell "current session of current window" (format "write text \"%s\"" cmd))))
```

This a been a nice boost in my work flow, and it was a lot of fun
exploring the weirdness of Lisp macros. Lots of things could be
improved, but this works for my simple uses. See the complete code in
my `emacs.d` Github repo:
[applescript.el](https://github.com/zacwood9/.emacs.d/blob/master/lisp/applescript.el)
and
[iterm.el](https://github.com/zacwood9/.emacs.d/blob/master/lisp/iterm.el).
