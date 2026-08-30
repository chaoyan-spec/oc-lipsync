namespace PAPAluLive.Core;

public sealed class CharacterRuntime
{
    private int talkingIndex;

    public CharacterDefinition Definition { get; private set; }
    public CharacterDisplayState State { get; private set; } =
        CharacterDisplayState.Idle;

    public string CurrentAssetName => State switch
    {
        CharacterDisplayState.Idle => Definition.IdleAssetName,
        CharacterDisplayState.Talking => Definition.TalkingAssetNames[talkingIndex],
        _ => throw new InvalidOperationException("Unknown display state."),
    };

    public CharacterRuntime(CharacterDefinition definition)
    {
        if (definition.TalkingAssetNames.Count == 0)
        {
            throw new ArgumentException(
                "A character needs at least one talking asset.",
                nameof(definition));
        }

        Definition = definition;
    }

    public void SetState(CharacterDisplayState state)
    {
        State = state;
        if (state == CharacterDisplayState.Talking)
        {
            talkingIndex = 0;
        }
    }

    public void AdvanceTalkingFrame()
    {
        if (State != CharacterDisplayState.Talking)
        {
            return;
        }

        talkingIndex = (talkingIndex + 1) % Definition.TalkingAssetNames.Count;
    }

    public void SetCharacter(
        CharacterDefinition definition,
        CharacterDisplayState currentState)
    {
        if (definition.TalkingAssetNames.Count == 0)
        {
            throw new ArgumentException(
                "A character needs at least one talking asset.",
                nameof(definition));
        }

        Definition = definition;
        talkingIndex = 0;
        SetState(currentState);
    }
}
