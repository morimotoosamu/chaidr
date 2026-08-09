# chaidr: CHAID and Exhaustive CHAID Decision Trees

An implementation of the CHAID (Chi-squared Automatic Interaction
Detection) decision tree algorithm of Kass (1980)
[doi:10.2307/2986296](https://doi.org/10.2307/2986296) and the
Exhaustive CHAID variant of Biggs, de Ville, and Suen (1991)
[doi:10.1080/02664769100000005](https://doi.org/10.1080/02664769100000005)
, as specified in the 'IBM SPSS' Statistics Algorithms documentation.
Supports nominal, ordinal (with floating missing category), and
continuous predictors, and nominal, ordinal, and continuous response
variables using Pearson chi-squared, Goodman row-effects, and one-way
ANOVA F tests respectively. Includes prediction, rule extraction, gains
and lift analysis, validation on holdout data, and visualization via
base graphics, 'Graphviz' DOT, 'plotly', and conversion to 'partykit'
objects.

## See also

Useful links:

- <https://github.com/morimotoosamu/chaidr>

- <https://morimotoosamu.github.io/chaidr/>

- Report bugs at <https://github.com/morimotoosamu/chaidr/issues>

## Author

**Maintainer**: Osamu Morimoto <galactic.supermarket@gmail.com>
\[copyright holder\]

Authors:

- Osamu Morimoto <galactic.supermarket@gmail.com> \[copyright holder\]
