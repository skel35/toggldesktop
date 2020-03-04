using System;
using System.Collections.Generic;
using System.IO;
using System.Reactive.Disposables;
using Xunit;

namespace TogglDesktop.Tests
{
    public class LibraryFixture : IDisposable
    {
        public List<Toggl.TogglTimeEntryView> TimeEntries { get; private set; }
        public Toggl.TogglTimeEntryView RunningEntry { get; private set; }
        public bool IsRunning { get; private set; }
        private readonly IDisposable _subscriptions;

        public string MeJson = File.ReadAllText("me.json");

        public LibraryFixture()
        {
            Toggl.Env = "test";
            _subscriptions = new CompositeDisposable(
                Toggl.OnTimeEntryList.Subscribe(x => TimeEntries = x.list),
                Toggl.OnRunningTimerState.Subscribe(te =>
                {
                    RunningEntry = te;
                    IsRunning = true;
                }),
                Toggl.OnStoppedTimerState.Subscribe(_ =>
                {
                    RunningEntry = default;
                    IsRunning = false;
                }));
            Assert.True(Toggl.StartUI("0.0.0", new ulong[0]));
            Toggl.ClearCache();
            Toggl.SetManualMode(false);
        }

        public void Dispose()
        {
            Toggl.Clear();
            _subscriptions.Dispose();
        }
    }
}