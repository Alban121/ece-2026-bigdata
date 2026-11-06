{% test positive(model, column_name) %}
-- Generic test: returns the rows where the column is zero or negative
select {{ column_name }}
from {{ model }}
where {{ column_name }} <= 0
{% endtest %}
