/*
Peek Copyright (c) 2015-2016 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

public abstract class AbstractCommandScreenRecorder : Object, ScreenRecorder {
  protected Pid pid;
  protected IOChannel input;
  protected string temp_file;

  public bool is_recording { get; protected set; default = false; }

  public int framerate { get; set; default = 15; }

  public abstract bool record (RecordingArea area);

  protected bool spawn_record_command (string[] args) {
    try {
      int standard_input;
      Process.spawn_async_with_pipes (null, args, null,
        SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
        null, out pid, out standard_input);

      input = new IOChannel.unix_new (standard_input);

      ChildWatch.add (pid, (pid, status) => {
        // Triggered when the child indicated by pid exits
        Process.close_pid (pid);
        handle_process_exit (status);
      });

      is_recording = true;
      recording_started ();
      return true;
    } catch (SpawnError e) {
      stderr.printf ("Error: %s\n", e.message);
      return false;
    }
  }

  public File? stop () {
    stdout.printf ("Recording stopped\n");
    stop_command ();
    var file = convert_to_gif();
    FileUtils.remove (temp_file);
    is_recording = false;
    recording_finished (file);
    return file;
  }

  public void cancel () {
    if (is_recording) {
      stop_command ();
      FileUtils.remove (temp_file);
      is_recording = false;
      recording_aborted (0);
    }
  }

  protected abstract void handle_process_exit (int status);

  protected abstract void stop_command ();

  protected static string create_temp_file (string extension) throws FileError {
    string file_name;
    var fd = FileUtils.open_tmp ("peekXXXXXX." + extension, out file_name);
    FileUtils.close (fd);
    return file_name;
  }

  private File? convert_to_gif () {
    try {
      double delay = (100.0 / framerate);
      var output_file = create_temp_file ("gif");
      string[] argv = {
        "convert",
        "-set", "delay", delay.to_string(),
        "-layers", "Optimize",
        temp_file,
        output_file
      };

      Process.spawn_sync (null, argv, null,
        SpawnFlags.SEARCH_PATH, null);
      return File.new_for_path (output_file);
    } catch (SpawnError e) {
     stderr.printf ("Error: %s\n", e.message);
     return null;
    } catch (FileError e) {
     stderr.printf ("Error: %s\n", e.message);
     return null;
    }
  }
}
