package types

import (
	"encoding/json"
	"math/rand/v2"
	"time"
	"uuid"
)

type Event struct {
	Timestamp time.Time
	AppId     string
	KeyId     string
	Cluster   *string  `json:"cluster"`
	Tags      []string `json:"tags" binding:"required"`
	Data      any      `json:"data"`
}

type EventBuffer struct {
	Events            []*Event
	EventBufferLength int
	NextEventPtr      int
	Timeout           int
}

// Do this by value, so we can pass it down a channel,
// create a new set of buffers, and not worry about
// races on the pointered structure.
func NewEventBuffer(bufferLength int) EventBuffer {
	eb := EventBuffer{
		Events: make([]*Event, bufferLength),
	}
	eb.NextEventPtr = 0
	eb.EventBufferLength = bufferLength

	return eb
}

func (eb *EventBuffer) AddEvent(e *Event) bool {
	// Warning: this must be strictly sequential; this is
	// not a parallel-safe pointer update.
	eb.Events[eb.NextEventPtr] = e
	eb.NextEventPtr += 1
	// If we have a pointer >= the length, we're full
	return eb.NextEventPtr >= eb.EventBufferLength
}

func RandomEvent(a App) Event {
	var cluster string
	if rand.IntN(100) < 10 {
		cluster = uuid.New().String()
	}

	source := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	tags := make([]string, 0)
	for range rand.IntN(3) + 1 {
		randomIndex := rand.IntN(len(source))
		randomByte := source[randomIndex]
		tags = append(tags, string(randomByte))
	}

	var data any
	switch []string{"int", "string", "map"}[rand.IntN(3)] {
	case "int":
		data = rand.IntN(100)
	case "string":
		data = uuid.New().String()
	case "map":
		data = map[string]any{
			uuid.New().String(): rand.IntN(100),
			uuid.New().String(): rand.IntN(100),
			uuid.New().String(): rand.IntN(100),
		}
	}

	dataAsJson, _ := json.Marshal(data)

	return Event{
		Timestamp: time.Now(),
		AppId:     a.AppId,
		KeyId:     a.KeyId,
		Cluster:   &cluster,
		Tags:      tags,
		// TagString
		Data: dataAsJson,
	}
}
