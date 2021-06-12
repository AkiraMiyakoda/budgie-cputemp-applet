public class CpuTempPlugin : Budgie.Plugin, Peas.ExtensionBase {
	public Budgie.Applet get_panel_widget(string uuid) {
		return new CpuTempApplet(uuid);
	}
}

[GtkTemplate (ui="/com/github/tarkah/budgie-cputemp-applet/settings.ui")]
public class CpuTempSettings : Gtk.Grid {
	Settings? settings = null;

	[GtkChild]
	private unowned Gtk.ComboBoxText? combobox;

	[GtkChild]
	private unowned Gtk.Entry? sensor_entry;

	[GtkChild]
	private unowned Gtk.Switch? fscale_switch;

	[GtkChild]
	private unowned Gtk.Switch? show_sign_switch;

	public CpuTempSettings(Settings? settings) {
		this.settings = settings;

		populate_combobox();

		settings.bind("sensor",    sensor_entry,     "text",  SettingsBindFlags.DEFAULT);
		settings.bind("fscale",    fscale_switch,    "state", SettingsBindFlags.DEFAULT);
		settings.bind("show-sign", show_sign_switch, "state", SettingsBindFlags.DEFAULT);
	}

	protected void populate_combobox() {
		var sensors = Sensors.list_sensors();

		foreach (var sensor in sensors) {
			this.combobox.append_text(sensor.display_name());
		}
	}
}

public class CpuTempApplet : Budgie.Applet {
	public string uuid { public set; public get; }

	protected Gtk.EventBox widget;
	protected Gtk.Box layout;
	protected Gtk.Label temp_label;
	protected Gtk.Image? applet_icon;
	protected ThemedIcon? cpu_chip_icon;

	private Settings? settings;

	private double temp;
	private Sensors.Sensor[] sensors;
	private Sensors.Sensor? sensor;

	public override bool supports_settings() {
		return true;
	}

	public override Gtk.Widget? get_settings_ui() {
		return new CpuTempSettings(this.get_applet_settings(uuid));
	}

	public CpuTempApplet(string uuid) {
		Object(uuid: uuid);
		
		// Setup settings
		settings_schema = "com.github.tarkah.budgie-cputemp-applet";
		settings_prefix = "/com/github/tarkah/budgie-cputemp-applet";

		settings = this.get_applet_settings(uuid);
		settings.changed.connect(on_settings_change);

		// Get sensors
		get_sensors();
		on_settings_change("sensor");

		widget = new Gtk.EventBox();

		layout = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
		layout.margin_start = 8;
		layout.margin_end = 8;

		widget.add(layout);

		cpu_chip_icon = new ThemedIcon.from_names( {"chip-cpu-symbolic"} );
		applet_icon = new Gtk.Image.from_gicon(cpu_chip_icon, Gtk.IconSize.MENU);
		layout.pack_start(applet_icon, false, false, 0);

		temp_label = new Gtk.Label("0.0°");
		temp_label.valign = Gtk.Align.CENTER;

		layout.pack_start(temp_label, false, false, 0);

		temp = 0.0;
		update_temp();

		Timeout.add_seconds_full(Priority.LOW, 1, update_temp);

		add(widget);
		show_all();
	}

	void on_settings_change(string key) {
		if (key != "sensor") {
			return;
		}

		string sensor_name = settings.get_string(key);

		foreach (var sensor in this.sensors) {
			if (sensor.display_name() == sensor_name) {
				this.sensor = sensor;
			}
		}

		update_temp();
	}

	protected void get_sensors() {
		this.sensors = Sensors.list_sensors();
	}

	protected void fetch_temp() {
		if (sensor != null) {
			double temp = Sensors.fetch_temp(sensor.input_path);

			if (temp > 0.0) {
				this.temp = temp;
			}
		}
	}

	protected bool update_temp() {
		fetch_temp();

		var old_format = temp_label.get_label();
		var format = format_temp();

		if (old_format == format) {
			return true;
		}

		temp_label.set_markup(format);

		queue_draw();

		return true;
	}

	protected string format_temp() {
		var temp = this.temp;
		var fscale = settings.get_boolean("fscale");
		if (fscale) {
			temp = temp * 1.8 + 32;
		}

		var show_sign = settings.get_boolean("show-sign");
		var sign = "";
		if (show_sign) {
			sign = fscale ? "F" : "C";
		}

		return "%.1f°%s".printf(temp, sign);
	}
}

[ModuleInit]
public void peas_register_types(TypeModule module) {
	// boilerplate - all modules need this
	var objmodule = module as Peas.ObjectModule;
	objmodule.register_extension_type(typeof(Budgie.Plugin), typeof(CpuTempPlugin));
}
