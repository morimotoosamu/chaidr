# Changelog

## chaidr 0.1.0

CRAN release: 2026-08-08

- Initial CRAN release.
- [`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md)
  fits CHAID and Exhaustive CHAID decision trees following the IBM SPSS
  Statistics Algorithms specification, with nominal, ordinal (floating
  missing category), and continuous predictors, and nominal, ordinal,
  and continuous responses.
- [`chaid_control()`](https://morimotoosamu.github.io/chaidr/reference/chaid_control.md)
  exposes all algorithm parameters with SPSS-compatible defaults, plus
  an `adjust_across` extension for multiplicity adjustment across
  predictors.
- [`predict()`](https://rdrr.io/r/stats/predict.html) returns class
  labels, class probabilities, or terminal node ids.
- Inspection and reporting:
  [`chaid_table()`](https://morimotoosamu.github.io/chaidr/reference/chaid_table.md),
  [`chaid_rules()`](https://morimotoosamu.github.io/chaidr/reference/chaid_rules.md),
  [`chaid_importance()`](https://morimotoosamu.github.io/chaidr/reference/chaid_importance.md),
  [`chaid_gains()`](https://morimotoosamu.github.io/chaidr/reference/chaid_gains.md),
  and
  [`chaid_validate()`](https://morimotoosamu.github.io/chaidr/reference/chaid_validate.md).
- Visualization: base graphics
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html), ‘Graphviz’
  DOT export via
  [`chaid_dot()`](https://morimotoosamu.github.io/chaidr/reference/chaid_dot.md)
  /
  [`chaid_graphviz()`](https://morimotoosamu.github.io/chaidr/reference/chaid_dot.md),
  interactive trees via
  [`chaid_plotly()`](https://morimotoosamu.github.io/chaidr/reference/chaid_plotly.md),
  and conversion to ‘partykit’ objects via
  [`chaid_as_party()`](https://morimotoosamu.github.io/chaidr/reference/chaid_as_party.md).
