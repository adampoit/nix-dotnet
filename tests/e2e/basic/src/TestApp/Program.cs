namespace TestApp;

public class Calculator
{
    public int Add(int a, int b) => a + b;

    public int Multiply(int a, int b) => a * b;

    public int Subtract(int a, int b) => a - b;
}

public class Program
{
    public static void Main(string[] args)
    {
        var calculator = new Calculator();
        Console.WriteLine($"2 + 3 = {calculator.Add(2, 3)}");
        Console.WriteLine($"4 * 5 = {calculator.Multiply(4, 5)}");
        Console.WriteLine($"10 - 6 = {calculator.Subtract(10, 6)}");
    }
}
