A simple tool that can be used as a simple database of invoices your company
sends and a generator of invoices in LaTeX that can be converted to pdf using
following commands:

```
# Generate LaTeX files
$ ruby sync.rb

# Convert tex files to pdf
$ for f in *.tex; do; pdftex &pdflatex $f; done
```
