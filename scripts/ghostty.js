// Shared by osascript and the persistent bridge. Address the Ghostty process
// that owns this process tree, rather than whichever instance Launch Services
// happens to resolve for the application name.
ObjC.import('AppKit');

var targetPID;
function owningGhosttyPID() {
  if (targetPID) return targetPID;
  var apps = $.NSRunningApplication.runningApplicationsWithBundleIdentifier('com.mitchellh.ghostty');
  var candidates = {};
  for (var i = 0; i < apps.count; i++) {
    candidates[apps.objectAtIndex(i).processIdentifier] = true;
  }
  var pipe = $.NSPipe.pipe;
  var task = $.NSTask.alloc.init;
  task.launchPath = '/bin/ps';
  task.arguments = ['-axo', 'pid=,ppid='];
  task.standardOutput = pipe;
  task.launch;
  var data = pipe.fileHandleForReading.readDataToEndOfFile;
  task.waitUntilExit;
  if (task.terminationStatus !== 0) throw Error('Could not read the process tree');
  var rows = ObjC.unwrap($.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding));
  var parents = {};
  rows.split('\n').forEach(function (row) {
    var pair = row.trim().split(/\s+/);
    parents[Number(pair[0])] = Number(pair[1]);
  });
  var pid = $.NSProcessInfo.processInfo.processIdentifier;
  while (pid > 1) {
    if (candidates[pid]) return (targetPID = pid);
    pid = parents[pid];
  }
  throw Error('No owning Ghostty process found');
}

// Four-character event/property codes come from Ghostty.sdef. Constructing the
// address ourselves preserves the PID; JXA Application(pid) can resolve by bundle.
var D = $.NSAppleEventDescriptor;
function code(s) {
  return ((s.charCodeAt(0) << 24) | (s.charCodeAt(1) << 16) |
    (s.charCodeAt(2) << 8) | s.charCodeAt(3)) >>> 0;
}

function send(pid, suite, name, params) {
  var event = D.appleEventWithEventClassEventIDTargetDescriptorReturnIDTransactionID(
    code(suite), code(name), D.descriptorWithProcessIdentifier(pid), -1, 0
  );
  Object.keys(params || {}).forEach(function (key) {
    event.setDescriptorForKeyword(params[key], code(key));
  });
  var error = Ref();
  var reply = event.sendEventWithOptionsTimeoutError($.NSAppleEventSendDefaultOptions, 1, error);
  if (reply.isNil()) throw Error(ObjC.unwrap(error[0].localizedDescription));
  var err = reply.descriptorForKeyword(code('errn'));
  if (!err.isNil() && err.int32Value) {
    var message = reply.descriptorForKeyword(code('errs'));
    throw Error('Apple Event error ' + err.int32Value +
      (message.isNil() ? '' : ': ' + ObjC.unwrap(message.stringValue)));
  }
  return reply.descriptorForKeyword(code('----'));
}

function prop(name, from) {
  var obj = D.recordDescriptor;
  obj.setDescriptorForKeyword(D.descriptorWithTypeCode(code('prop')), code('want'));
  obj.setDescriptorForKeyword(D.descriptorWithEnumCode(code('prop')), code('form'));
  obj.setDescriptorForKeyword(D.descriptorWithTypeCode(code(name)), code('seld'));
  obj.setDescriptorForKeyword(from || D.nullDescriptor, code('from'));
  return obj.coerceToDescriptorType(code('obj '));
}

function terminal(id) {
  var obj = D.recordDescriptor;
  obj.setDescriptorForKeyword(D.descriptorWithTypeCode(code('Gtrm')), code('want'));
  obj.setDescriptorForKeyword(D.descriptorWithEnumCode(code('ID  ')), code('form'));
  obj.setDescriptorForKeyword(D.descriptorWithString(id), code('seld'));
  obj.setDescriptorForKeyword(D.nullDescriptor, code('from'));
  return obj.coerceToDescriptorType(code('obj '));
}

function focusedTerminalID() {
  // ID of focused terminal / selected tab / front window (Ghostty.sdef).
  return ObjC.unwrap(send(owningGhosttyPID(), 'core', 'getd', {
    '----': prop('ID  ', prop('GTfT', prop('GWsT', prop('GFWn'))))
  }).stringValue);
}

function performAction(terminalID, action) {
  return !!send(owningGhosttyPID(), 'Ghst', 'PfAc', {
    '----': D.descriptorWithString(action), 'GonT': terminal(terminalID)
  }).booleanValue;
}

function run(argv) {
  if (argv[0] === 'focused-terminal-id' && argv.length === 1) return focusedTerminalID();
  if (argv[0] === 'perform-action' && argv.length === 3) return performAction(argv[1], argv[2]);
  throw Error('Expected focused-terminal-id or perform-action <terminal ID> <action>');
}
