using Newtonsoft.Json;

var payload = new { greeting = "hello", count = 42 };
Console.WriteLine(JsonConvert.SerializeObject(payload));
