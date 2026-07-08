using Xunit;
using TestApp;

namespace TestApp.Tests;

public class CalculatorTests
{
    private readonly Calculator _calculator = new();

    [Fact]
    public void Add_TwoNumbers_ReturnsSum()
    {
        var result = _calculator.Add(2, 3);
        Assert.Equal(5, result);
    }

    [Fact]
    public void Multiply_TwoNumbers_ReturnsProduct()
    {
        var result = _calculator.Multiply(4, 5);
        Assert.Equal(20, result);
    }

    [Fact]
    public void Subtract_TwoNumbers_ReturnsDifference()
    {
        var result = _calculator.Subtract(10, 6);
        Assert.Equal(4, result);
    }

    [Theory]
    [InlineData(1, 1, 2)]
    [InlineData(0, 0, 0)]
    [InlineData(-1, 1, 0)]
    [InlineData(100, 200, 300)]
    public void Add_VariousInputs_ReturnsExpected(int a, int b, int expected)
    {
        var result = _calculator.Add(a, b);
        Assert.Equal(expected, result);
    }
}
