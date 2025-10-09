# Демонстрационный пример отчёта в Markdown

## Задание

Приближённо вычислить число $\pi$ с помощью [произведения Валлиса](https://ru.wikipedia.org/wiki/%D0%A4%D0%BE%D1%80%D0%BC%D1%83%D0%BB%D0%B0_%D0%92%D0%B0%D0%BB%D0%BB%D0%B8%D1%81%D0%B0):

$$ \frac{\pi}{2} = \prod_{i=1}^{\infty} \frac{4i^2}{4i^2 - 1}. $$

## Результаты вычислений

Очередной множитель произведения на Python:

```python
def wallis_multiplier(i):
    i_squared_times_4 = 4 * i * i
    return i_squared_times_4 / (i_squared_times_4 - 1)
```

При разнице последних значений произведения $\pi / 2$ менее `1e-7` вычисленное значение $\pi = 3.1411963131348553$.

![Pi convergence plot](img/convergence_plot.png)

Произведение Валлиса сходится очень медленно, поэтому рекомендуется использовать более эффективные методы вычисления числа $\pi$.


## Список использованных источников:

1. [Matplotlib cheatsheets and handouts](https://matplotlib.org/cheatsheets/)
2. [Markdown Cheat Sheet](https://www.markdownguide.org/cheat-sheet/)
3. [Writing mathematical expressions](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/writing-mathematical-expressions)
