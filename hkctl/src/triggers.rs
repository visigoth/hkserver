use chrono::{NaiveDateTime, Duration};
use clap::{ArgMatches};
use std::boxed::Box;
use std::future::Future;
use std::pin::Pin;
use tonic::transport::Channel;
use crate::hkservice::home_kit_service_client::HomeKitServiceClient;
use crate::hkservice::{EnumerateTriggersRequest, EnumerateTriggersResponse};
use crate::hkservice::enumerate_triggers_request::EnabledFilter;
use crate::hkservice::trigger_information::Trigger;
use crate::hkservice::{EventTriggerInformation, TimerTriggerInformation};
use crate::hkservice::{
    event_information::Event,
    EventInformation,
    LocationEventInformation,
    CalendarEventInformation,
    SignificantTimeEventInformation,
    DurationEventInformation,
    CharacteristicEventInformation,
    CharacteristicThresholdRangeEventInformation,
    PresenceEventInformation,
    PresenceEventType,
    PresenceEventUserType,
};
use crate::hkservice::event_trigger_information::ActivationState;


impl std::fmt::Display for ActivationState {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl std::fmt::Display for PresenceEventType {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl std::fmt::Display for PresenceEventUserType {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

fn print_timer_trigger(timer_trigger: &TimerTriggerInformation) {
    let trigger = timer_trigger.trigger.as_ref().unwrap();
    println!("  Trigger: {}", trigger.name);
    println!("    UUID: {}", trigger.uuid);
    println!("    Type: Timer");
    println!("    Is Enabled: {}", trigger.is_enabled);
    println!("    Last Fire Date (UTC): {}", NaiveDateTime::from_timestamp(trigger.last_fire_date as i64, 0));
    println!("    Next Fire Date (UTC): {}", NaiveDateTime::from_timestamp(timer_trigger.fire_date as i64, 0));
    println!("    Recurrence: {}", Duration::seconds(timer_trigger.recurrence as i64));
    println!("    Action Sets: ({})", trigger.action_sets.len());
    trigger.action_sets.iter().for_each(|action_set| {
        println!("      Action Set: {} ({})", action_set.name, action_set.uuid);
    });
}

fn print_location_event(location_event: &LocationEventInformation) {
    println!("      Event: {}", location_event.uuid);
    println!("        Type: Location");
    println!("        Notify On Entry: {}", location_event.notify_on_entry);
    println!("        Notify On Exit: {}", location_event.notify_on_exit);
    if let Some(ref region) = location_event.region {
        println!("        Region:");
        println!("          Center: ({}, {})", region.center.as_ref().unwrap().latitude, region.center.as_ref().unwrap().longitude);
        println!("          Radius: {}", region.radius);
    };
}

fn print_calendar_event(calendar_event: &CalendarEventInformation) {
    println!("      Event: {}", calendar_event.uuid);
    println!("        Type: Calendar");
    println!("        Fire Date: {}", NaiveDateTime::from_timestamp(calendar_event.fire_date as i64, 0));
}

fn print_significant_time_event(significant_time_event: &SignificantTimeEventInformation) {
    println!("      Event: {}", significant_time_event.uuid);
    println!("        Type: Significant Time");
    println!("        Significant Event: {}", significant_time_event.significant_event);
    match significant_time_event.offset {
        0 => println!("        Offset: None"),
        o => println!("        Offset: {}", Duration::seconds(o as i64)),
    };
}

fn print_duration_event(duration_event: &DurationEventInformation) {
    println!("      Event: {}", duration_event.uuid);
    println!("        Type: Duration");
    println!("        Duration: {}", Duration::seconds(duration_event.duration as i64));
}

fn print_characteristic_event(characteristic_event: &CharacteristicEventInformation) {
    println!("      Event: {}", characteristic_event.uuid);
    println!("        Type: Characteristic Event");
    let characteristic = characteristic_event.characteristic.as_ref().unwrap();
    println!("        Characteristic: {} ({})", characteristic.name, characteristic.uuid);
    match characteristic_event.trigger_value.as_ref() {
        Some(value) => println!("        Trigger Value: {}", value),
        None => println!("        Trigger Value: Any Change"),
    };
}

fn print_characteristic_threshold_range_event(characteristic_threshold_range_event: &CharacteristicThresholdRangeEventInformation) {
    println!("      Event: {}", characteristic_threshold_range_event.uuid);
    println!("        Type: Characteristic Threshold Range");
    let characteristic = characteristic_threshold_range_event.characteristic.as_ref().unwrap();
    println!("        Characteristic: {} ({})", characteristic.name, characteristic.uuid);
    let range = characteristic_threshold_range_event.range.as_ref().unwrap();
    match &range.min_value {
        Some(ref min_value) => println!("        Min: {}", min_value),
        None => println!("        Min: None"),
    };
    match &range.max_value {
        Some(ref max_value) => println!("        Max: {}", max_value),
        None => println!("        Max: None"),
    };
}

fn print_presence_event(presence_event: &PresenceEventInformation) {
    println!("      Event: {}", presence_event.uuid);
    println!("        Type: Presence");
    println!("        Event Type: {}", presence_event.presence_event);
    println!("        Users: {}", presence_event.presence_user);
}

fn print_event(event: &EventInformation) {
    match event.event.as_ref().unwrap() {
        Event::LocationEvent(le) => print_location_event(le),
        Event::CalendarEvent(ce) => print_calendar_event(ce),
        Event::SignificantTimeEvent(ste) => print_significant_time_event(ste),
        Event::DurationEvent(de) => print_duration_event(de),
        Event::CharacteristicEvent(ce) => print_characteristic_event(ce),
        Event::CharacteristicThresholdRangeEvent(ctre) => print_characteristic_threshold_range_event(ctre),
        Event::PresenceEvent(pe) => print_presence_event(pe),
    };
}

fn print_event_trigger(event_trigger: &EventTriggerInformation) {
    let trigger = event_trigger.trigger.as_ref().unwrap();
    println!("  Trigger: {}", trigger.name);
    println!("    UUID: {}", trigger.uuid);
    println!("    Type: Event");
    println!("    Is Enabled: {}", trigger.is_enabled);
    println!("    Last Fire Date (UTC): {}", NaiveDateTime::from_timestamp(trigger.last_fire_date as i64, 0));
    println!("    Activation State: {}", event_trigger.activation_state());
    println!("    Executes Once: {}", event_trigger.executes_once);
    println!("    Events: ({})", event_trigger.events.len());
    event_trigger.events.iter().for_each(|event| {
        print_event(event);
    });
    println!("    End Events: ({})", event_trigger.end_events.len());
    event_trigger.end_events.iter().for_each(|event| {
        print_event(event);
    });
    println!("    Action Sets: ({})", trigger.action_sets.len());
    trigger.action_sets.iter().for_each(|action_set| {
        println!("      Action Set: {} ({})", action_set.name, action_set.uuid);
    });
}

fn print_response(response: &EnumerateTriggersResponse) {
    if let Some(ref home) = &response.home {
        println!("Home: {}", home.name);
    }
    println!("Triggers ({}):", response.triggers.len());
    response.triggers.iter().for_each(|trigger| {
        match trigger.trigger.as_ref().unwrap() {
            Trigger::Event(ref event_trigger) => print_event_trigger(event_trigger),
            Trigger::Timer(ref timer_trigger) => print_timer_trigger(timer_trigger),
        };
    });
}

fn parse_timestamp(s: Option<&str>) -> u64 {
    match s {
        Some(s) => match NaiveDateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S") {
            Ok(dt) => dt.timestamp() as u64,
            _ => panic!("Unable to parse {} as datetime", s),
        }
        None => 0,
    }
}

async fn _run(matches: ArgMatches, mut client: HomeKitServiceClient<Channel>) -> Result<(), Box<dyn std::error::Error>> {
    let before = parse_timestamp(matches.value_of("before"));
    let after = parse_timestamp(matches.value_of("after"));
    let enabled_filter_mode = match matches.value_of("enabled").unwrap_or("either") {
        "either" => EnabledFilter::NoFilter,
        "true" => EnabledFilter::EnabledOnly,
        "false" => EnabledFilter::DisabledOnly,
        _ => panic!("Unexpected enabled filter value"),
    };
    let response = client.enumerate_triggers(
        EnumerateTriggersRequest {
            home: matches.value_of("home").unwrap_or("").to_string(),
            name_filter: matches.value_of("name").unwrap_or("").to_string(),
            enabled_filter: enabled_filter_mode as i32,
            before: before,
            after: after,
        }).await?.into_inner();
    print_response(&response);
    Ok(())
}

pub fn run(matches: ArgMatches, client: HomeKitServiceClient<Channel>) -> Pin<Box<dyn Future<Output = Result<(), Box<dyn std::error::Error>>>>> {
    Box::pin(_run(matches, client))
}
