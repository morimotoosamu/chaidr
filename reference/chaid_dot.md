# Render a CHAID tree as Graphviz DOT

`chaid_dot()` generates a publication-quality Graphviz DOT description
of the tree using base R only. It can be rendered with
`chaid_graphviz()` (which uses 'DiagrammeR', bundling viz.js so no
Graphviz binary is needed) or written to a `.gv` file and rendered
externally with `dot -Tpng` / `dot -Tsvg`.

## Usage

``` r
chaid_dot(
  fit,
  palette = NULL,
  rankdir = "TB",
  label_len = 28,
  legend = TRUE,
  file = NULL
)

# S3 method for class 'chaid_dot'
print(x, ...)

chaid_graphviz(fit, ...)
```

## Arguments

- fit:

  A fitted `"chaid"` object returned by
  [`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md).

- palette:

  Vector of class colours for categorical responses (default
  `grDevices::hcl.colors(n, "Dark 3")`, matching
  [`plot.chaid()`](https://morimotoosamu.github.io/chaidr/reference/plot.chaid.md)).
  For continuous responses node fills use a white-to-steelblue gradient
  of the node means.

- rankdir:

  Graph direction: `"TB"` (top to bottom, default) or `"LR"` (left to
  right).

- label_len:

  Maximum number of characters for edge (split group) labels.

- legend:

  Logical. Add a legend node with the class colours (categorical
  responses only).

- file:

  Optional path; when given, the DOT source is also written there in
  UTF-8 for use with the external `dot` command.

- x:

  A `"chaid_dot"` object.

- ...:

  For `chaid_graphviz()`, arguments passed on to `chaid_dot()`; ignored
  by [`print()`](https://rdrr.io/r/base/print.html).

## Value

For `chaid_dot()`, the DOT source as a character string of class
`"chaid_dot"` (returned invisibly; its
[`print()`](https://rdrr.io/r/base/print.html) method outputs the
source). For `chaid_graphviz()`, an 'htmlwidget' as returned by
[`DiagrammeR::grViz()`](https://rich-iannone.github.io/DiagrammeR/reference/grViz.html).

## See also

[`plot.chaid()`](https://morimotoosamu.github.io/chaidr/reference/plot.chaid.md),
[`chaid_plotly()`](https://morimotoosamu.github.io/chaidr/reference/chaid_plotly.md)

## Examples

``` r
fit <- chaid(Species ~ ., data = iris,
             control = chaid_control(min_parent = 30, min_child = 10))
dot <- chaid_dot(fit)
```
