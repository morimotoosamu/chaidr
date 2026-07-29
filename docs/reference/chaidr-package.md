# chaidr: CHAID and Exhaustive CHAID Decision Trees

A base R implementation of the CHAID (Chi-squared Automatic Interaction
Detection) and Exhaustive CHAID decision tree algorithms as specified in
the IBM SPSS Statistics Algorithms documentation. Supports nominal,
ordinal (with floating missing category), and continuous predictors, and
nominal, ordinal, and continuous response variables using Pearson
chi-squared, Goodman row-effects, and one-way ANOVA F tests
respectively. Includes prediction, rule extraction, gains and lift
analysis, validation on holdout data, and visualization via base
graphics, 'Graphviz' DOT, 'plotly', and conversion to 'partykit'
objects.

## Author

**Maintainer**: Osamu Morimoto <galactic.supermarket@gmail.com>

Authors:

- Osamu Morimoto <galactic.supermarket@gmail.com>
