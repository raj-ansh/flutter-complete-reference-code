import 'package:flutter/material.dart';

enum Watering { daily, weekly, rarely }

// #docregion controls
/// Checkbox, switch, radio group, slider and dropdown, all driven by state.
class ControlsDemo extends StatefulWidget {
  const ControlsDemo({super.key});

  @override
  State<ControlsDemo> createState() => _ControlsDemoState();
}

class _ControlsDemoState extends State<ControlsDemo> {
  bool _indoor = true;
  bool _notify = false;
  Watering? _watering = Watering.weekly;
  double _light = 60;
  RangeValues _temperature = const RangeValues(15, 25);
  String? _soil = 'loam';

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        CheckboxListTile(
          title: const Text('Grown indoors'),
          value: _indoor,
          onChanged: (v) => setState(() => _indoor = v ?? false),
        ),
        SwitchListTile(
          title: const Text('Reminders'),
          subtitle: const Text('Notify me when it is time to water'),
          value: _notify,
          onChanged: (v) => setState(() => _notify = v),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text('Watering'),
        ),
        // A RadioGroup owns the selected value for all Radios beneath it.
        RadioGroup<Watering>(
          groupValue: _watering,
          onChanged: (v) => setState(() => _watering = v),
          child: Column(
            children: [
              for (final w in Watering.values)
                RadioListTile<Watering>(title: Text(w.name), value: w),
            ],
          ),
        ),
        ListTile(
          title: Text('Light: ${_light.round()}%'),
          subtitle: Slider(
            value: _light,
            min: 0,
            max: 100,
            divisions: 10,
            label: '${_light.round()}%',
            onChanged: (v) => setState(() => _light = v),
          ),
        ),
        ListTile(
          title: Text(
            'Temperature: ${_temperature.start.round()}'
            ' to ${_temperature.end.round()} °C',
          ),
          subtitle: RangeSlider(
            values: _temperature,
            min: 0,
            max: 40,
            onChanged: (v) => setState(() => _temperature = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownMenu<String>(
            label: const Text('Soil'),
            initialSelection: _soil,
            onSelected: (v) => setState(() => _soil = v),
            dropdownMenuEntries: const [
              DropdownMenuEntry(value: 'loam', label: 'Loam'),
              DropdownMenuEntry(value: 'sand', label: 'Sand'),
              DropdownMenuEntry(value: 'clay', label: 'Clay'),
            ],
          ),
        ),
      ],
    );
  }
}
// #enddocregion controls
