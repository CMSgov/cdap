package csp

import (
	"context"
	"testing"
	"time"

	"github.com/navapbc/its-log/internal/types"
)

func TestContext(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	buffer_length := 3
	buffer_flushwaitsec := 3

	// Build the process network for buffering and
	// saving events that come in via the API
	ch_eb := make(chan types.EventBuffer)
	ch_evt := make(chan *types.Event)

	go Enqueue(ctx, ch_evt, ch_eb, buffer_length, buffer_flushwaitsec)
	cancel()
}

func TestEnqueueTimesOut(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	buffer_length := 3
	buffer_flushwaitsec := 3

	// Build the process network for buffering and
	// saving events that come in via the API
	ch_eb := make(chan types.EventBuffer)
	ch_evt := make(chan *types.Event)

	go Enqueue(ctx, ch_evt, ch_eb, buffer_length, buffer_flushwaitsec)

	// Start the clock
	start := time.Now()
	go func() {
		// Enqueue one event
		ch_evt <- &types.Event{}
	}()
	// Block on reading the channel
	<-ch_eb
	// Measure the elapsed t ime
	delta := time.Since(start)
	// Did we wait long enough?
	if delta < time.Duration(buffer_flushwaitsec) {
		t.Error("buffer flushed too fast")
	}
	// Shut down the Enqueue function
	cancel()
}

func TestEnqueueImmediateFlush(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	buffer_length := 3
	buffer_flushwaitsec := 5
	done := make(chan bool)

	go func() {
		// Build the process network for buffering and
		// saving events that come in via the API
		ch_eb := make(chan types.EventBuffer)
		ch_evt := make(chan *types.Event)

		go Enqueue(ctx, ch_evt, ch_eb, buffer_length, buffer_flushwaitsec)

		// Start the clock
		start := time.Now()

		go func() {
			// Enqueue more events than the buffer size
			// Do this async, so the block on the next line can wait.
			for range buffer_length * 2 {
				ch_evt <- &types.Event{}
			}
		}()
		// Block on reading the channel
		<-ch_eb
		// Measure the elapsed time
		delta := time.Since(start)
		// Did we wait long enough?
		if time.Duration(delta.Seconds()) > time.Duration(buffer_flushwaitsec) {
			t.Errorf("buffer did not flush as soon as full")
		}

		// Shut down the Enqueue function
		cancel()
		done <- true
	}()

	select {
	case <-time.After(time.Duration(buffer_length) * time.Second):
		t.Fatalf("Test timed out after %d seconds", buffer_length)
	case <-done:
		// Test finished successfully
	}
}
