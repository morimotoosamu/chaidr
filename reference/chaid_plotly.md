# Interactive CHAID tree plot with plotly

Draws the tree as an interactive 'plotly' htmlwidget with zoom, pan and
hover information (reaching rule, class distribution and split details
for each node). The widget can be embedded directly in R Markdown
documents or saved as HTML.

## Usage

``` r
chaid_plotly(fit, palette = NULL, label_len = 20, ...)
```

## Arguments

- fit:

  A fitted `"chaid"` object returned by
  [`chaid()`](https://morimotoosamu.github.io/chaidr/reference/chaid.md).

- palette:

  Vector of class colours for categorical responses (default
  `grDevices::hcl.colors(n, "Dark 3")`, matching
  [`plot.chaid()`](https://morimotoosamu.github.io/chaidr/reference/plot.chaid.md)).

- label_len:

  Maximum number of characters for edge (split group) labels.

- ...:

  Ignored.

## Value

A 'plotly' htmlwidget.

## See also

[`plot.chaid()`](https://morimotoosamu.github.io/chaidr/reference/plot.chaid.md),
[`chaid_dot()`](https://morimotoosamu.github.io/chaidr/reference/chaid_dot.md)

## Examples

``` r
fit <- chaid(Species ~ ., data = iris,
             control = chaid_control(min_parent = 30, min_child = 10))
chaid_plotly(fit)

{"x":{"visdat":{"1aef2a350525":["function () ","plotlyVisDat"],"1aef506142ff":["function () ","data"],"1aef2495283e":["function () ","data"],"1aef13759525":["function () ","data"],"1aef4122feb4":["function () ","data"],"1aef4934bdf3":["function () ","data"],"1aef20be6235":["function () ","data"]},"cur_data":"1aef20be6235","attrs":{"1aef506142ff":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"xend":{},"yend":{},"type":"scatter","mode":"lines","line":{"color":"grey","width":1},"hoverinfo":"none","showlegend":false,"inherit":true},"1aef2495283e":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"text":{},"type":"scatter","mode":"text","textfont":{"size":9,"color":"grey40"},"hoverinfo":"none","showlegend":false,"inherit":true},"1aef13759525":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"type":"scatter","mode":"markers","name":"setosa","marker":{"size":22,"symbol":"square","color":"#E16A86","line":{"color":"grey30","width":1}},"text":{},"hoverinfo":"text","inherit":true},"1aef4122feb4":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"type":"scatter","mode":"markers","name":"versicolor","marker":{"size":22,"symbol":"square","color":"#50A315","line":{"color":"grey30","width":1}},"text":{},"hoverinfo":"text","inherit":true},"1aef4934bdf3":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"type":"scatter","mode":"markers","name":"virginica","marker":{"size":22,"symbol":"square","color":"#009ADE","line":{"color":"grey30","width":1}},"text":{},"hoverinfo":"text","inherit":true},"1aef20be6235":{"alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"x":{},"y":{},"text":{},"type":"scatter","mode":"text","textfont":{"size":10},"hoverinfo":"none","showlegend":false,"inherit":true}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"title":{"text":"CHAID (chaid): Species"},"xaxis":{"domain":[0,1],"automargin":true,"showgrid":false,"zeroline":false,"showticklabels":false,"title":""},"yaxis":{"domain":[0,1],"automargin":true,"showgrid":false,"zeroline":false,"showticklabels":false,"title":""},"hovermode":"closest","plot_bgcolor":"rgba(0,0,0,0)","showlegend":true},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[3.5,1,null,3.5,2,null,3.5,3,null,3.5,4,null,3.5,5,null,3.5,6],"y":[-0.080000000000000002,-0.88,null,-0.080000000000000002,-0.88,null,-0.080000000000000002,-0.88,null,-0.080000000000000002,-0.88,null,-0.080000000000000002,-0.88,null,-0.080000000000000002,-0.88],"type":"scatter","mode":"lines","line":{"color":"grey","width":1},"hoverinfo":["none","none",null,"none","none",null,"none","none",null,"none","none",null,"none","none",null,"none","none"],"showlegend":false,"marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"xaxis":"x","yaxis":"y","frame":null},{"x":[1,2,3,4,5,6],"y":[-0.76000000000000001,-0.76000000000000001,-0.76000000000000001,-0.76000000000000001,-0.76000000000000001,-0.76000000000000001],"text":["<= 1.6","(1.6, 3.8]","(3.8, 4.6]","(4.6, 4.9]","(4.9, 5.3]","> 5.3"],"type":"scatter","mode":"text","textfont":{"size":9,"color":"grey40"},"hoverinfo":["none","none","none","none","none","none"],"showlegend":false,"marker":{"color":"rgba(255,127,14,1)","line":{"color":"rgba(255,127,14,1)"}},"error_y":{"color":"rgba(255,127,14,1)"},"error_x":{"color":"rgba(255,127,14,1)"},"line":{"color":"rgba(255,127,14,1)"},"xaxis":"x","yaxis":"y","frame":null},{"x":[3.5,1],"y":[0,-1],"type":"scatter","mode":"markers","name":"setosa","marker":{"color":"#E16A86","size":22,"symbol":"square","line":{"color":"grey30","width":1}},"text":["<b>[1]<\/b>  n=150 (100.0%)<br>prediction: <b>setosa<\/b><br>setosa: 33.3%<br>versicolor: 33.3%<br>virginica: 33.3%<br>split: Petal.Length (adj.p=1.354e-44)<br><i>(all cases)<\/i>","<b>[2]<\/b>  n=44 (29.3%)<br>prediction: <b>setosa<\/b><br>setosa: 100.0%<br>versicolor: 0.0%<br>virginica: 0.0%<br><i>Petal.Length &lt;= 1.6<\/i>"],"hoverinfo":["text","text"],"error_y":{"color":"rgba(44,160,44,1)"},"error_x":{"color":"rgba(44,160,44,1)"},"line":{"color":"rgba(44,160,44,1)"},"xaxis":"x","yaxis":"y","frame":null},{"x":[2,3,4],"y":[-1,-1,-1],"type":"scatter","mode":"markers","name":"versicolor","marker":{"color":"#50A315","size":22,"symbol":"square","line":{"color":"grey30","width":1}},"text":["<b>[3]<\/b>  n=14 (9.3%)<br>prediction: <b>versicolor<\/b><br>setosa: 42.9%<br>versicolor: 57.1%<br>virginica: 0.0%<br><i>Petal.Length in (1.6, 3.8]<\/i>","<b>[4]<\/b>  n=32 (21.3%)<br>prediction: <b>versicolor<\/b><br>setosa: 0.0%<br>versicolor: 96.9%<br>virginica: 3.1%<br><i>Petal.Length in (3.8, 4.6]<\/i>","<b>[5]<\/b>  n=14 (9.3%)<br>prediction: <b>versicolor<\/b><br>setosa: 0.0%<br>versicolor: 64.3%<br>virginica: 35.7%<br><i>Petal.Length in (4.6, 4.9]<\/i>"],"hoverinfo":["text","text","text"],"error_y":{"color":"rgba(214,39,40,1)"},"error_x":{"color":"rgba(214,39,40,1)"},"line":{"color":"rgba(214,39,40,1)"},"xaxis":"x","yaxis":"y","frame":null},{"x":[5,6],"y":[-1,-1],"type":"scatter","mode":"markers","name":"virginica","marker":{"color":"#009ADE","size":22,"symbol":"square","line":{"color":"grey30","width":1}},"text":["<b>[6]<\/b>  n=16 (10.7%)<br>prediction: <b>virginica<\/b><br>setosa: 0.0%<br>versicolor: 12.5%<br>virginica: 87.5%<br><i>Petal.Length in (4.9, 5.3]<\/i>","<b>[7]<\/b>  n=30 (20.0%)<br>prediction: <b>virginica<\/b><br>setosa: 0.0%<br>versicolor: 0.0%<br>virginica: 100.0%<br><i>Petal.Length &gt; 5.3<\/i>"],"hoverinfo":["text","text"],"error_y":{"color":"rgba(148,103,189,1)"},"error_x":{"color":"rgba(148,103,189,1)"},"line":{"color":"rgba(148,103,189,1)"},"xaxis":"x","yaxis":"y","frame":null},{"x":[3.5,1,2,3,4,5,6],"y":[-0.17000000000000001,-1.1699999999999999,-1.1699999999999999,-1.1699999999999999,-1.1699999999999999,-1.1699999999999999,-1.1699999999999999],"text":["[1] setosa","[2] setosa","[3] versicolor","[4] versicolor","[5] versicolor","[6] virginica","[7] virginica"],"type":"scatter","mode":"text","textfont":{"size":10},"hoverinfo":["none","none","none","none","none","none","none"],"showlegend":false,"marker":{"color":"rgba(140,86,75,1)","line":{"color":"rgba(140,86,75,1)"}},"error_y":{"color":"rgba(140,86,75,1)"},"error_x":{"color":"rgba(140,86,75,1)"},"line":{"color":"rgba(140,86,75,1)"},"xaxis":"x","yaxis":"y","frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}
```
