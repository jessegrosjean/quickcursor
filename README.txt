About:

QuickCursor is menu item that allows you to edit text from any application in your favorite text editor*. Unlike custom “edit in” plugin solutions QuickCursor provides a standard open source solution that uses public API's and doesn’t require input manager hacks to work.

QuickCursor works by reading a string value from the source application via the current AXUIElement. Next it sets up a ODBEditor session with the preferred editor. When the preferred editor modifies the string QuickCursor writes that value back into the source application via the AXUIElement.

Todo:

- Doesn't work with Mail.app. Mail.app's text area is a AXWebArea. It seems that the default kAXValueAttribute doesn't work for reading and writing AXWebArea's text. Need to find out how to read write text from AXWebArea and handle as a special case.
- String is written back into source application with [QCUIElement setValue:]. This generally works, but it seems to change the value behind the scenes... this can mess up undo stacks and such in the destination app. Needs to be some documentation that describes how the source app can be made aware of these changes and how to custom handle them.
- Doesn't seem to work with BBEdit editor.

Thanks,
Jesse Grosjean
jesse@hogbaysoftware.com
