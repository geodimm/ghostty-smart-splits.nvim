// All Apple Events, including object lookups and cleanup, address this PID.
// JXA Application(pid) can resolve the bundle's first instance instead.
ObjC.import('Foundation');
function run(argv) {
  eval(ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(argv[0], $.NSUTF8StringEncoding, null)));
  var pid = argv[1] === 'owner' ? owningGhosttyPID() : Number(argv[1]);
  var operation = argv[2];
  var running = $.NSRunningApplication.runningApplicationWithProcessIdentifier(pid);
  var alive = !running.isNil() && !running.terminated;
  if (operation === 'running') return alive;
  if (!alive) throw Error('Test Ghostty process is no longer running');
  function configuration(command) {
    var fields = D.recordDescriptor;
    fields.setDescriptorForKeyword(D.descriptorWithString(command), code('GScC'));
    return send(pid, 'Ghst', 'NSCf', { 'GScS': fields });
  }
  if (operation === 'quit') { send(pid, 'aevt', 'quit'); return; }
  if (operation === 'new') {
    var win = send(pid, 'Ghst', 'NWin', argv[3] ? { 'GNwS': configuration(argv[3]) } : {});
    return ObjC.unwrap(send(pid, 'core', 'getd', {
      '----': prop('ID  ', prop('GTfT', prop('GWsT', win)))
    }).stringValue);
  }
  if (operation === 'focused') {
    return ObjC.unwrap(send(pid, 'core', 'getd', {
      '----': prop('ID  ', prop('GTfT', prop('GWsT', prop('GFWn'))))
    }).stringValue);
  }
  var term = terminal(argv[3]);
  if (operation === 'split') {
    var params = {
      '----': term, 'GSpd': D.descriptorWithEnumCode(code('GSrt'))
    };
    if (argv[4]) params.GSpS = configuration(argv[4]);
    var created = send(pid, 'Ghst', 'Splt', params);
    return ObjC.unwrap(send(pid, 'core', 'getd', { '----': prop('ID  ', created) }).stringValue);
  }
  if (operation === 'focus') { send(pid, 'Ghst', 'Fcus', { '----': term }); return; }
  if (operation === 'close') { send(pid, 'Ghst', 'Clos', { '----': term }); return; }
  if (operation === 'text') {
    send(pid, 'Ghst', 'InTx', { '----': D.descriptorWithString(argv[4]), 'GItT': term });
    return;
  }
  if (operation === 'key') {
    var params = { '----': D.descriptorWithString(argv[4]),
      'GKeM': D.descriptorWithString(argv[5]), 'GKeT': term };
    send(pid, 'Ghst', 'SKey', params);
    params.GKeA = D.descriptorWithEnumCode(code('GIrl'));
    send(pid, 'Ghst', 'SKey', params);
    return;
  }
  throw Error('Unknown E2E operation: ' + operation);
}
