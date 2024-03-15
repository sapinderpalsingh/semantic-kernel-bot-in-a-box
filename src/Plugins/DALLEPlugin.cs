using System.ComponentModel;
using System.Threading.Tasks;
using Azure;
using Microsoft.SemanticKernel;
using Microsoft.BotBuilderSamples;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Schema;
using Azure.AI.OpenAI;
using System.Collections.Generic;

namespace Plugins;
public class DALLEPlugin
{
    private readonly OpenAIClient _aoaiClient;
    private ITurnContext<IMessageActivity> _turnContext;
    private string _dalleModelName;

    public DALLEPlugin(ConversationData conversationData, ITurnContext<IMessageActivity> turnContext, OpenAIClient aoaiClient, string dalleModelName)
    {
        _aoaiClient = aoaiClient;
        _turnContext = turnContext;
        _dalleModelName = dalleModelName;
    }



    [KernelFunction, Description("Generate images from descriptions.")]
    public async Task<string> GenerateImages(
        [Description("The description of the images to be generated")] string prompt,
        [Description("The number of images to generate. If not specified, I should use 1")] int n
    )
    {
        await _turnContext.SendActivityAsync($"Generating images with the description \"{prompt}\"...");
        Response<ImageGenerations> imageGenerations = await _aoaiClient.GetImageGenerationsAsync(
            new ImageGenerationOptions()
            {
                DeploymentName = _dalleModelName,
                Prompt = prompt,
                Size = ImageSize.Size1024x1024,
                ImageCount = 1
            });

        List<object> images = new();
        images.Add(
            new {
                type="TextBlock",
                text="Here are the generated images.",
                size="large"
            }
        );
        foreach (ImageGenerationData img in imageGenerations.Value.Data)
            images.Add(new { type = "Image", url = img.Url.AbsoluteUri });
        object adaptiveCardJson = new
        {
            type = "AdaptiveCard",
            version = "1.0",
            body = images
        };

        var adaptiveCardAttachment = new Microsoft.Bot.Schema.Attachment()
        {
            ContentType = "application/vnd.microsoft.card.adaptive",
            Content = adaptiveCardJson,
        };
        await _turnContext.SendActivityAsync(MessageFactory.Attachment(adaptiveCardAttachment));
        return "Images were generated successfully and already sent to user.";
    }

}