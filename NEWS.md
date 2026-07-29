# chaidr 0.1.0

* Initial CRAN release.
* `chaid()` fits CHAID and Exhaustive CHAID decision trees following the
  IBM SPSS Statistics Algorithms specification, with nominal, ordinal
  (floating missing category), and continuous predictors, and nominal,
  ordinal, and continuous responses.
* `chaid_control()` exposes all algorithm parameters with SPSS-compatible
  defaults, plus an `adjust_across` extension for multiplicity adjustment
  across predictors.
* `predict()` returns class labels, class probabilities, or terminal node
  ids.
* Inspection and reporting: `chaid_table()`, `chaid_rules()`,
  `chaid_importance()`, `chaid_gains()`, and `chaid_validate()`.
* Visualization: base graphics `plot()`, 'Graphviz' DOT export via
  `chaid_dot()` / `chaid_graphviz()`, interactive trees via
  `chaid_plotly()`, and conversion to 'partykit' objects via
  `chaid_as_party()`.
