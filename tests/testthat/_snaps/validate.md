# print がエラーなく動き、目的変数のない newdata はエラー

    Code
      chaid_validate(fit, data.frame(a = 1))
    Condition
      Error in `chaid_validate()`:
      ! chaid_validate: response 'species' not found in newdata

