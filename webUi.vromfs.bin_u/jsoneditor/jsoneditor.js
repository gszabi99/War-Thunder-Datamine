
(function () {


function JSONEditor (container, options, json) {
    if (!(this instanceof JSONEditor)) {
        throw new Error('JSONEditor constructor called without "new".');
    }

    if (arguments.length) {
        this._create(container, options, json);
    }
}


JSONEditor.modes = {};


JSONEditor.prototype._create = function (container, options, json) {
    this.container = container;
    this.options = options || {};
    this.json = json || {};

    var mode = this.options.mode || 'tree';
    this.setMode(mode);
};


JSONEditor.prototype._delete = function () {};


JSONEditor.prototype.set = function (json) {
    this.json = json;
};


JSONEditor.prototype.get = function () {
    return this.json;
};


JSONEditor.prototype.setText = function (jsonText) {
    this.json = util.parse(jsonText);
};


JSONEditor.prototype.getText = function () {
    return JSON.stringify(this.json);
};


JSONEditor.prototype.setName = function (name) {
    if (!this.options) {
        this.options = {};
    }
    this.options.name = name;
};


JSONEditor.prototype.getName = function () {
    return this.options && this.options.name;
};


JSONEditor.prototype.setMode = function (mode) {
    var container = this.container,
        options = util.extend({}, this.options),
        data,
        name;

    options.mode = mode;
    var config = JSONEditor.modes[mode];
    if (config) {
        try {
            if (config.data == 'text') {
                                name = this.getName();
                data = this.getText();

                this._delete();
                util.clear(this);
                util.extend(this, config.editor.prototype);
                this._create(container, options);

                this.setName(name);
                this.setText(data);
            }
            else {
                                name = this.getName();
                data = this.get();

                this._delete();
                util.clear(this);
                util.extend(this, config.editor.prototype);
                this._create(container, options);

                this.setName(name);
                this.set(data);
            }

            if (typeof config.load === 'function') {
                try {
                    config.load.call(this);
                }
                catch (err) {}
            }
        }
        catch (err) {
            this._onError(err);
        }
    }
    else {
        throw new Error('Unknown mode "' + options.mode + '"');
    }
};


JSONEditor.prototype._onError = function(err) {
        if (typeof this.onError === 'function') {
        util.log('WARNING: JSONEditor.onError is deprecated. ' +
            'Use options.error instead.');
        this.onError(err);
    }

    if (this.options && typeof this.options.error === 'function') {
        this.options.error(err);
    }
    else {
        throw err;
    }
};


function TreeEditor(container, options, json) {
    if (!(this instanceof TreeEditor)) {
        throw new Error('TreeEditor constructor called without "new".');
    }

    this._create(container, options, json);
}


TreeEditor.prototype._create = function (container, options, json) {
        if (typeof(JSON) == 'undefined') {
        throw new Error ('Your browser does not support JSON. \n\n' +
            'Please install the newest version of your browser.\n' +
            '(all modern browsers support JSON).');
    }

    if (!container) {
        throw new Error('No container element provided.');
    }
    this.container = container;
    this.dom = {};
    this.highlighter = new Highlighter();
    this.selection = undefined; 
    this._setOptions(options);

    if (this.options.history && !this.mode.view) {
        this.history = new History(this);
    }

    this._createFrame();
    this._createTable();

    this.set(json || {});
};


TreeEditor.prototype._delete = function () {
    if (this.frame && this.container && this.frame.parentNode == this.container) {
        this.container.removeChild(this.frame);
    }
};


TreeEditor.prototype._setOptions = function (options) {
    this.options = {
        search: true,
        history: true,
        mode: 'tree',
        name: undefined       };

        if (options) {
        for (var prop in options) {
            if (options.hasOwnProperty(prop)) {
                this.options[prop] = options[prop];
            }
        }

                if (options['enableSearch']) {
                        this.options.search = options['enableSearch'];
            util.log('WARNING: Option "enableSearch" is deprecated. Use "search" instead.');
        }
        if (options['enableHistory']) {
                        this.options.history = options['enableHistory'];
            util.log('WARNING: Option "enableHistory" is deprecated. Use "history" instead.');
        }
        if (options['mode'] == 'editor') {
                        this.options.mode = 'tree';
            util.log('WARNING: Mode "editor" is deprecated. Use "tree" instead.');
        }
        if (options['mode'] == 'viewer') {
                        this.options.mode = 'view';
            util.log('WARNING: Mode "viewer" is deprecated. Use "view" instead.');
        }
    }

        this.mode = {
        edit: (this.options.mode != 'view' && this.options.mode != 'form'),
        view: (this.options.mode == 'view'),
        form: (this.options.mode == 'form')
    };
};

TreeEditor.focusNode = undefined;


TreeEditor.prototype.set = function (json, name) {
        if (name) {
                util.log('Warning: second parameter "name" is deprecated. ' +
            'Use setName(name) instead.');
        this.options.name = name;
    }

        if (json instanceof Function || (json === undefined)) {
        this.clear();
    }
    else {
        this.content.removeChild(this.table);  
                var params = {
            'field': this.options.name,
            'value': json
        };
        var node = new Node(this, params);
        this._setRoot(node);

                var recurse = false;
        this.node.expand(recurse);

        this.content.appendChild(this.table);      }

        if (this.history) {
        this.history.clear();
    }
};


TreeEditor.prototype.get = function () {
        if (TreeEditor.focusNode) {
        TreeEditor.focusNode.blur();
    }

    if (this.node) {
        return this.node.getValue();
    }
    else {
        return undefined;
    }
};


TreeEditor.prototype.getText = function() {
    return JSON.stringify(this.get());
};


TreeEditor.prototype.setText = function(jsonText) {
    this.set(util.parse(jsonText));
};


TreeEditor.prototype.setName = function (name) {
    this.options.name = name;
    if (this.node) {
        this.node.updateField(this.options.name);
    }
};


TreeEditor.prototype.getName = function () {
    return this.options.name;
};


TreeEditor.prototype.clear = function () {
    if (this.node) {
        this.node.collapse();
        this.tbody.removeChild(this.node.getDom());
        delete this.node;
    }
};


TreeEditor.prototype._setRoot = function (node) {
    this.clear();

    this.node = node;

        this.tbody.appendChild(node.getDom());
};


TreeEditor.prototype.search = function (text) {
    var results;
    if (this.node) {
        this.content.removeChild(this.table);          results = this.node.search(text);
        this.content.appendChild(this.table);      }
    else {
        results = [];
    }

    return results;
};


TreeEditor.prototype.expandAll = function () {
    if (this.node) {
        this.content.removeChild(this.table);          this.node.expand();
        this.content.appendChild(this.table);      }
};


TreeEditor.prototype.collapseAll = function () {
    if (this.node) {
        this.content.removeChild(this.table);          this.node.collapse();
        this.content.appendChild(this.table);      }
};


TreeEditor.prototype._onAction = function (action, params) {
        if (this.history) {
        this.history.add(action, params);
    }

        if (this.options.change) {
        try {
            this.options.change();
        }
        catch (err) {
            util.log('Error in change callback: ', err);
        }
    }
};


TreeEditor.prototype.startAutoScroll = function (mouseY) {
    var me = this;
    var content = this.content;
    var top = util.getAbsoluteTop(content);
    var height = content.clientHeight;
    var bottom = top + height;
    var margin = 24;
    var interval = 50; 
    if ((mouseY < top + margin) && content.scrollTop > 0) {
        this.autoScrollStep = ((top + margin) - mouseY) / 3;
    }
    else if (mouseY > bottom - margin &&
            height + content.scrollTop < content.scrollHeight) {
        this.autoScrollStep = ((bottom - margin) - mouseY) / 3;
    }
    else {
        this.autoScrollStep = undefined;
    }

    if (this.autoScrollStep) {
        if (!this.autoScrollTimer) {
            this.autoScrollTimer = setInterval(function () {
                if (me.autoScrollStep) {
                    content.scrollTop -= me.autoScrollStep;
                }
                else {
                    me.stopAutoScroll();
                }
            }, interval);
        }
    }
    else {
        this.stopAutoScroll();
    }
};


TreeEditor.prototype.stopAutoScroll = function () {
    if (this.autoScrollTimer) {
        clearTimeout(this.autoScrollTimer);
        delete this.autoScrollTimer;
    }
    if (this.autoScrollStep) {
        delete this.autoScrollStep;
    }
};



TreeEditor.prototype.setSelection = function (selection) {
    if (!selection) {
        return;
    }

    if ('scrollTop' in selection && this.content) {
                this.content.scrollTop = selection.scrollTop;
    }
    if (selection.range) {
        util.setSelectionOffset(selection.range);
    }
    if (selection.dom) {
        selection.dom.focus();
    }
};


TreeEditor.prototype.getSelection = function () {
    return {
        dom: TreeEditor.domFocus,
        scrollTop: this.content ? this.content.scrollTop : 0,
        range: util.getSelectionOffset()
    };
};


TreeEditor.prototype.scrollTo = function (top, callback) {
    var content = this.content;
    if (content) {
        var editor = this;
                if (editor.animateTimeout) {
            clearTimeout(editor.animateTimeout);
            delete editor.animateTimeout;
        }
        if (editor.animateCallback) {
            editor.animateCallback(false);
            delete editor.animateCallback;
        }

                var height = content.clientHeight;
        var bottom = content.scrollHeight - height;
        var finalScrollTop = Math.min(Math.max(top - height / 4, 0), bottom);

                var animate = function () {
            var scrollTop = content.scrollTop;
            var diff = (finalScrollTop - scrollTop);
            if (Math.abs(diff) > 3) {
                content.scrollTop += diff / 3;
                editor.animateCallback = callback;
                editor.animateTimeout = setTimeout(animate, 50);
            }
            else {
                                if (callback) {
                    callback(true);
                }
                content.scrollTop = finalScrollTop;
                delete editor.animateTimeout;
                delete editor.animateCallback;
            }
        };
        animate();
    }
    else {
        if (callback) {
            callback(false);
        }
    }
};


TreeEditor.prototype._createFrame = function () {
        this.frame = document.createElement('div');
    this.frame.className = 'jsoneditor';
    this.container.appendChild(this.frame);

        var editor = this;
    var onEvent = function (event) {
        editor._onEvent(event);
    };
    this.frame.onclick = function (event) {
        event = event || window.event;
        var target = event.target || event.srcElement;

        onEvent(event);

                        if (target.nodeName == 'BUTTON') {
            util.preventDefault(event);
        }
    };
    this.frame.oninput = onEvent;
    this.frame.onchange = onEvent;
    this.frame.onkeydown = onEvent;
    this.frame.onkeyup = onEvent;
    this.frame.oncut = onEvent;
    this.frame.onpaste = onEvent;
    this.frame.onmousedown = onEvent;
    this.frame.onmouseup = onEvent;
    this.frame.onmouseover = onEvent;
    this.frame.onmouseout = onEvent;
                util.addEventListener(this.frame, 'focus', onEvent, true);
    util.addEventListener(this.frame, 'blur', onEvent, true);
    this.frame.onfocusin = onEvent;      this.frame.onfocusout = onEvent; 
        this.menu = document.createElement('div');
    this.menu.className = 'menu';
    this.frame.appendChild(this.menu);

        var expandAll = document.createElement('button');
    expandAll.className = 'expand-all';
    expandAll.title = 'Expand all fields';
    expandAll.onclick = function () {
        editor.expandAll();
    };
    this.menu.appendChild(expandAll);

        var collapseAll = document.createElement('button');
    collapseAll.title = 'Collapse all fields';
    collapseAll.className = 'collapse-all';
    collapseAll.onclick = function () {
        editor.collapseAll();
    };
    this.menu.appendChild(collapseAll);

        if (this.history) {
                var separator = document.createElement('span');
        separator.innerHTML = '&nbsp;';
        this.menu.appendChild(separator);

                var undo = document.createElement('button');
        undo.className = 'undo';
        undo.title = 'Undo last action (Ctrl+Z)';
        undo.onclick = function () {
            editor._onUndo();
        };
        this.menu.appendChild(undo);
        this.dom.undo = undo;

                var redo = document.createElement('button');
        redo.className = 'redo';
        redo.title = 'Redo (Ctrl+Shift+Z)';
        redo.onclick = function () {
            editor._onRedo();
        };
        this.menu.appendChild(redo);
        this.dom.redo = redo;

                this.history.onChange = function () {
            undo.disabled = !editor.history.canUndo();
            redo.disabled = !editor.history.canRedo();
        };
        this.history.onChange();
    }

        if (this.options.search) {
        this.searchBox = new SearchBox(this, this.menu);
    }
};


TreeEditor.prototype._onUndo = function () {
    if (this.history) {
                this.history.undo();

                if (this.options.change) {
            this.options.change();
        }
    }
};


TreeEditor.prototype._onRedo = function () {
    if (this.history) {
                this.history.redo();

                if (this.options.change) {
            this.options.change();
        }
    }
};


TreeEditor.prototype._onEvent = function (event) {
    event = event || window.event;
    var target = event.target || event.srcElement;

    if (event.type == 'keydown') {
        this._onKeyDown(event);
    }

    if (event.type == 'focus') {
        TreeEditor.domFocus = target;
    }

    var node = Node.getNodeFromTarget(target);
    if (node) {
        node.onEvent(event);
    }
};


TreeEditor.prototype._onKeyDown = function (event) {
    var keynum = event.which || event.keyCode;
    var ctrlKey = event.ctrlKey;
    var shiftKey = event.shiftKey;
    var handled = false;

    if (keynum == 9) {                         setTimeout(function () {
                        util.selectContentEditable(TreeEditor.domFocus);
        }, 0);
    }

    if (this.searchBox) {
        if (ctrlKey && keynum == 70) {             this.searchBox.dom.search.focus();
            this.searchBox.dom.search.select();
            handled = true;
        }
        else if (keynum == 114 || (ctrlKey && keynum == 71)) {             var focus = true;
            if (!shiftKey) {
                                this.searchBox.next(focus);
            }
            else {
                                this.searchBox.previous(focus);
            }

            handled = true;
        }
    }

    if (this.history) {
        if (ctrlKey && !shiftKey && keynum == 90) {                         this._onUndo();
            handled = true;
        }
        else if (ctrlKey && shiftKey && keynum == 90) {                         this._onRedo();
            handled = true;
        }
    }

    if (handled) {
        util.preventDefault(event);
        util.stopPropagation(event);
    }
};


TreeEditor.prototype._createTable = function () {
    var contentOuter = document.createElement('div');
    contentOuter.className = 'outer';
    this.contentOuter = contentOuter;

    this.content = document.createElement('div');
    this.content.className = 'content';
    contentOuter.appendChild(this.content);

    this.table = document.createElement('table');
    this.table.className = 'content';
    this.content.appendChild(this.table);

            var ieVersion = util.getInternetExplorerVersion();
    if (ieVersion == 8) {
        this.content.style.overflow = 'scroll';
    }

            var col;
    this.colgroupContent = document.createElement('colgroup');
    if (this.mode.edit) {
        col = document.createElement('col');
        col.width = "24px";
        this.colgroupContent.appendChild(col);
    }
    col = document.createElement('col');
    col.width = "24px";
    this.colgroupContent.appendChild(col);
    col = document.createElement('col');
    this.colgroupContent.appendChild(col);
    this.table.appendChild(this.colgroupContent);

    this.tbody = document.createElement('tbody');
    this.table.appendChild(this.tbody);

    this.frame.appendChild(contentOuter);
};

JSONEditor.modes.tree = {
    editor: TreeEditor,
    data: 'json'
};
JSONEditor.modes.view = {
    editor: TreeEditor,
    data: 'json'
};
JSONEditor.modes.form = {
    editor: TreeEditor,
    data: 'json'
};
JSONEditor.modes.editor = {
    editor: TreeEditor,
    data: 'json'
};
JSONEditor.modes.viewer = {
    editor: TreeEditor,
    data: 'json'
};


function TextEditor(container, options, json) {
    if (!(this instanceof TextEditor)) {
        throw new Error('TextEditor constructor called without "new".');
    }

    this._create(container, options, json);
}


TextEditor.prototype._create = function (container, options, json) {
        if (typeof(JSON) == 'undefined') {
        throw new Error('Your browser does not support JSON. \n\n' +
            'Please install the newest version of your browser.\n' +
            '(all modern browsers support JSON).');
    }

        options = options || {};
    this.options = options;
    if (options.indentation) {
        this.indentation = Number(options.indentation);
    }
    this.mode = (options.mode == 'code') ? 'code' : 'text';
    if (this.mode == 'code') {
                if (typeof ace === 'undefined') {
            this.mode = 'text';
            util.log('WARNING: Cannot load code editor, Ace library not loaded. ' +
                'Falling back to plain text editor');
        }
        if (util.getInternetExplorerVersion() == 8) {
            this.mode = 'text';
            util.log('WARNING: Cannot load code editor, Ace is not supported on IE8. ' +
                'Falling back to plain text editor');
        }
    }

    var me = this;
    this.container = container;
    this.editor = undefined;        this.textarea = undefined;      this.indentation = 4;       
    this.width = container.clientWidth;
    this.height = container.clientHeight;

    this.frame = document.createElement('div');
    this.frame.className = 'jsoneditor';
    this.frame.onclick = function (event) {
                util.preventDefault(event);
    };

        this.menu = document.createElement('div');
    this.menu.className = 'menu';
    this.frame.appendChild(this.menu);

        var buttonFormat = document.createElement('button');
        buttonFormat.className = 'format';
    buttonFormat.title = 'Format JSON data, with proper indentation and line feeds';
        this.menu.appendChild(buttonFormat);
    buttonFormat.onclick = function () {
        try {
            me.format();
        }
        catch (err) {
            me._onError(err);
        }
    };

        var buttonCompact = document.createElement('button');
        buttonCompact.className = 'compact';
    buttonCompact.title = 'Compact JSON data, remove all whitespaces';
        this.menu.appendChild(buttonCompact);
    buttonCompact.onclick = function () {
        try {
            me.compact();
        }
        catch (err) {
            me._onError(err);
        }
    };

    this.content = document.createElement('div');
    this.content.className = 'outer';
    this.frame.appendChild(this.content);

    this.container.appendChild(this.frame);

    if (this.mode == 'code') {
        this.editorDom = document.createElement('div');
        this.editorDom.style.height = '100%';         this.editorDom.style.width = '100%';         this.content.appendChild(this.editorDom);

        var editor = ace.edit(this.editorDom);
        editor.setTheme('ace/theme/jsoneditor');
        editor.setShowPrintMargin(false);
        editor.setFontSize(13);
        editor.getSession().setMode('ace/mode/json');
        editor.getSession().setUseSoftTabs(true);
        editor.getSession().setUseWrapMode(true);
        this.editor = editor;

        var poweredBy = document.createElement('a');
        poweredBy.appendChild(document.createTextNode('powered by ace'));
        poweredBy.href = 'http://ace.ajax.org';
        poweredBy.target = '_blank';
        poweredBy.className = 'poweredBy';
        poweredBy.onclick = function () {
                                                window.open(poweredBy.href, poweredBy.target);
        };
        this.menu.appendChild(poweredBy);

        if (options.change) {
                        editor.on('change', function () {
                options.change();
            });
        }
    }
    else {
                var textarea = document.createElement('textarea');
        textarea.className = 'content';
        textarea.spellcheck = false;
        this.content.appendChild(textarea);
        this.textarea = textarea;

        if (options.change) {
                        if (this.textarea.oninput === null) {
                this.textarea.oninput = function () {
                    options.change();
                }
            }
            else {
                                this.textarea.onchange = function () {
                    options.change();
                }
            }
        }
    }

        if (typeof(json) == 'string') {
        this.setText(json);
    }
    else {
        this.set(json);
    }
};


TextEditor.prototype._delete = function () {
    if (this.frame && this.container && this.frame.parentNode == this.container) {
        this.container.removeChild(this.frame);
    }
};


TextEditor.prototype._onError = function(err) {
        if (typeof this.onError === 'function') {
        util.log('WARNING: JSONEditor.onError is deprecated. ' +
            'Use options.error instead.');
        this.onError(err);
    }

    if (this.options && typeof this.options.error === 'function') {
        this.options.error(err);
    }
    else {
        throw err;
    }
};


TextEditor.prototype.compact = function () {
    var json = util.parse(this.getText());
    this.setText(JSON.stringify(json));
};


TextEditor.prototype.format = function () {
    var json = util.parse(this.getText());
    this.setText(JSON.stringify(json, null, this.indentation));
};


TextEditor.prototype.focus = function () {
    if (this.textarea) {
        this.textarea.focus();
    }
    if (this.editor) {
        this.editor.focus();
    }
};


TextEditor.prototype.resize = function () {
    if (this.editor) {
        var force = false;
        this.editor.resize(force);
    }
};


TextEditor.prototype.set = function(json) {
    this.setText(JSON.stringify(json, null, this.indentation));
};


TextEditor.prototype.get = function() {
    return util.parse(this.getText());
};


TextEditor.prototype.getText = function() {
    if (this.textarea) {
        return this.textarea.value;
    }
    if (this.editor) {
        return this.editor.getValue();
    }
    return '';
};


TextEditor.prototype.setText = function(jsonText) {
    if (this.textarea) {
        this.textarea.value = jsonText;
    }
    if (this.editor) {
        this.editor.setValue(jsonText, -1);
    }
};

JSONEditor.modes.text = {
    editor: TextEditor,
    data: 'text',
    load: TextEditor.prototype.format
};
JSONEditor.modes.code = {
    editor: TextEditor,
    data: 'text',
    load: TextEditor.prototype.format
};


function Node (editor, params) {
    
    this.editor = editor;
    this.dom = {};
    this.expanded = false;

    if(params && (params instanceof Object)) {
        this.setField(params.field, params.fieldEditable);
        this.setValue(params.value, params.type);
    }
    else {
        this.setField('');
        this.setValue(null);
    }
};


Node.prototype.setParent = function(parent) {
    this.parent = parent;
};


Node.prototype.setField = function(field, fieldEditable) {
    this.field = field;
    this.fieldEditable = (fieldEditable == true);
};


Node.prototype.getField = function() {
    if (this.field === undefined) {
        this._getDomField();
    }

    return this.field;
};


Node.prototype.setValue = function(value, type) {
    var childValue, child;

        var childs = this.childs;
    if (childs) {
        while (childs.length) {
            this.removeChild(childs[0]);
        }
    }

    
    this.type = this._getType(value);

        if (type && type != this.type) {
        if (type == 'string' && this.type == 'auto') {
            this.type = type;
        }
        else {
            throw new Error('Type mismatch: ' +
                'cannot cast value of type "' + this.type +
                ' to the specified type "' + type + '"');
        }
    }

    if (this.type == 'array') {
                this.childs = [];
        for (var i = 0, iMax = value.length; i < iMax; i++) {
            childValue = value[i];
            if (childValue !== undefined && !(childValue instanceof Function)) {
                                child = new Node(this.editor, {
                    'value': childValue
                });
                this.appendChild(child);
            }
        }
        this.value = '';
    }
    else if (this.type == 'object') {
                this.childs = [];
        for (var childField in value) {
            if (value.hasOwnProperty(childField)) {
                childValue = value[childField];
                if (childValue !== undefined && !(childValue instanceof Function)) {
                                        child = new Node(this.editor, {
                        'field': childField,
                        'value': childValue
                    });
                    this.appendChild(child);
                }
            }
        }
        this.value = '';
    }
    else {
                this.childs = undefined;
        this.value = value;
        
    }
};


Node.prototype.getValue = function() {
    
    if (this.type == 'array') {
        var arr = [];
        this.childs.forEach (function (child) {
            arr.push(child.getValue());
        });
        return arr;
    }
    else if (this.type == 'object') {
        var obj = {};
        this.childs.forEach (function (child) {
            obj[child.getField()] = child.getValue();
        });
        return obj;
    }
    else {
        if (this.value === undefined) {
            this._getDomValue();
        }

        return this.value;
    }
};


Node.prototype.getLevel = function() {
    return (this.parent ? this.parent.getLevel() + 1 : 0);
};


Node.prototype.clone = function() {
    var clone = new Node(this.editor);
    clone.type = this.type;
    clone.field = this.field;
    clone.fieldInnerText = this.fieldInnerText;
    clone.fieldEditable = this.fieldEditable;
    clone.value = this.value;
    clone.valueInnerText = this.valueInnerText;
    clone.expanded = this.expanded;

    if (this.childs) {
                var cloneChilds = [];
        this.childs.forEach(function (child) {
            var childClone = child.clone();
            childClone.setParent(clone);
            cloneChilds.push(childClone);
        });
        clone.childs = cloneChilds;
    }
    else {
                clone.childs = undefined;
    }

    return clone;
};


Node.prototype.expand = function(recurse) {
    if (!this.childs) {
        return;
    }

        this.expanded = true;
    if (this.dom.expand) {
        this.dom.expand.className = 'expanded';
    }

    this.showChilds();

    if (recurse != false) {
        this.childs.forEach(function (child) {
            child.expand(recurse);
        });
    }
};


Node.prototype.collapse = function(recurse) {
    if (!this.childs) {
        return;
    }

    this.hideChilds();

        if (recurse != false) {
        this.childs.forEach(function (child) {
            child.collapse(recurse);
        });

    }

        if (this.dom.expand) {
        this.dom.expand.className = 'collapsed';
    }
    this.expanded = false;
};


Node.prototype.showChilds = function() {
    var childs = this.childs;
    if (!childs) {
        return;
    }
    if (!this.expanded) {
        return;
    }

    var tr = this.dom.tr;
    var table = tr ? tr.parentNode : undefined;
    if (table) {
                var append = this.getAppend();
        var nextTr = tr.nextSibling;
        if (nextTr) {
            table.insertBefore(append, nextTr);
        }
        else {
            table.appendChild(append);
        }

                this.childs.forEach(function (child) {
            table.insertBefore(child.getDom(), append);
            child.showChilds();
        });
    }
};


Node.prototype.hide = function() {
    var tr = this.dom.tr;
    var table = tr ? tr.parentNode : undefined;
    if (table) {
        table.removeChild(tr);
    }
    this.hideChilds();
};



Node.prototype.hideChilds = function() {
    var childs = this.childs;
    if (!childs) {
        return;
    }
    if (!this.expanded) {
        return;
    }

        var append = this.getAppend();
    if (append.parentNode) {
        append.parentNode.removeChild(append);
    }

        this.childs.forEach(function (child) {
        child.hide();
    });
};



Node.prototype.appendChild = function(node) {
    if (this._hasChilds()) {
                node.setParent(this);
        node.fieldEditable = (this.type == 'object');
        if (this.type == 'array') {
            node.index = this.childs.length;
        }
        this.childs.push(node);

        if (this.expanded) {
                        var newTr = node.getDom();
            var appendTr = this.getAppend();
            var table = appendTr ? appendTr.parentNode : undefined;
            if (appendTr && table) {
                table.insertBefore(newTr, appendTr);
            }

            node.showChilds();
        }

        this.updateDom({'updateIndexes': true});
        node.updateDom({'recurse': true});
    }
};



Node.prototype.moveBefore = function(node, beforeNode) {
    if (this._hasChilds()) {
                        var tbody = (this.dom.tr) ? this.dom.tr.parentNode : undefined;
        if (tbody) {
            var trTemp = document.createElement('tr');
            trTemp.style.height = tbody.clientHeight + 'px';
            tbody.appendChild(trTemp);
        }

        if (node.parent) {
            node.parent.removeChild(node);
        }

        if (beforeNode instanceof AppendNode) {
            this.appendChild(node);
        }
        else {
            this.insertBefore(node, beforeNode);
        }

        if (tbody) {
            tbody.removeChild(trTemp);
        }
    }
};


Node.prototype.moveTo = function (node, index) {
    if (node.parent == this) {
                var currentIndex = this.childs.indexOf(node);
        if (currentIndex < index) {
                        index++;
        }
    }

    var beforeNode = this.childs[index] || this.append;
    this.moveBefore(node, beforeNode);
};


Node.prototype.insertBefore = function(node, beforeNode) {
    if (this._hasChilds()) {
        if (beforeNode == this.append) {
            
                        node.setParent(this);
            node.fieldEditable = (this.type == 'object');
            this.childs.push(node);
        }
        else {
                        var index = this.childs.indexOf(beforeNode);
            if (index == -1) {
                throw new Error('Node not found');
            }

                        node.setParent(this);
            node.fieldEditable = (this.type == 'object');
            this.childs.splice(index, 0, node);
        }

        if (this.expanded) {
                        var newTr = node.getDom();
            var nextTr = beforeNode.getDom();
            var table = nextTr ? nextTr.parentNode : undefined;
            if (nextTr && table) {
                table.insertBefore(newTr, nextTr);
            }

            node.showChilds();
        }

        this.updateDom({'updateIndexes': true});
        node.updateDom({'recurse': true});
    }
};


Node.prototype.insertAfter = function(node, afterNode) {
    if (this._hasChilds()) {
        var index = this.childs.indexOf(afterNode);
        var beforeNode = this.childs[index + 1];
        if (beforeNode) {
            this.insertBefore(node, beforeNode);
        }
        else {
            this.appendChild(node);
        }
    }
};


Node.prototype.search = function(text) {
    var results = [];
    var index;
    var search = text ? text.toLowerCase() : undefined;

        delete this.searchField;
    delete this.searchValue;

        if (this.field != undefined) {
        var field = String(this.field).toLowerCase();
        index = field.indexOf(search);
        if (index != -1) {
            this.searchField = true;
            results.push({
                'node': this,
                'elem': 'field'
            });
        }

                this._updateDomField();
    }

        if (this._hasChilds()) {
        
                if (this.childs) {
            var childResults = [];
            this.childs.forEach(function (child) {
                childResults = childResults.concat(child.search(text));
            });
            results = results.concat(childResults);
        }

                if (search != undefined) {
            var recurse = false;
            if (childResults.length == 0) {
                this.collapse(recurse);
            }
            else {
                this.expand(recurse);
            }
        }
    }
    else {
                if (this.value != undefined ) {
            var value = String(this.value).toLowerCase();
            index = value.indexOf(search);
            if (index != -1) {
                this.searchValue = true;
                results.push({
                    'node': this,
                    'elem': 'value'
                });
            }
        }

                this._updateDomValue();
    }

    return results;
};


Node.prototype.scrollTo = function(callback) {
    if (!this.dom.tr || !this.dom.tr.parentNode) {
                var parent = this.parent;
        var recurse = false;
        while (parent) {
            parent.expand(recurse);
            parent = parent.parent;
        }
    }

    if (this.dom.tr && this.dom.tr.parentNode) {
        this.editor.scrollTo(this.dom.tr.offsetTop, callback);
    }
};


Node.focusElement = undefined;


Node.prototype.focus = function(elementName) {
    Node.focusElement = elementName;

    if (this.dom.tr && this.dom.tr.parentNode) {
        var dom = this.dom;

        switch (elementName) {
            case 'drag':
                if (dom.drag) {
                    dom.drag.focus();
                }
                else {
                    dom.menu.focus();
                }
                break;

            case 'menu':
                dom.menu.focus();
                break;

            case 'expand':
                if (this._hasChilds()) {
                    dom.expand.focus();
                }
                else if (dom.field && this.fieldEditable) {
                    dom.field.focus();
                    util.selectContentEditable(dom.field);
                }
                else if (dom.value && !this._hasChilds()) {
                    dom.value.focus();
                    util.selectContentEditable(dom.value);
                }
                else {
                    dom.menu.focus();
                }
                break;

            case 'field':
                if (dom.field && this.fieldEditable) {
                    dom.field.focus();
                    util.selectContentEditable(dom.field);
                }
                else if (dom.value && !this._hasChilds()) {
                    dom.value.focus();
                    util.selectContentEditable(dom.value);
                }
                else if (this._hasChilds()) {
                    dom.expand.focus();
                }
                else {
                    dom.menu.focus();
                }
                break;

            case 'value':
            default:
                if (dom.value && !this._hasChilds()) {
                    dom.value.focus();
                    util.selectContentEditable(dom.value);
                }
                else if (dom.field && this.fieldEditable) {
                    dom.field.focus();
                    util.selectContentEditable(dom.field);
                }
                else if (this._hasChilds()) {
                    dom.expand.focus();
                }
                else {
                    dom.menu.focus();
                }
                break;
        }
    }
};


Node.select = function(editableDiv) {
    setTimeout(function () {
        util.selectContentEditable(editableDiv);
    }, 0);
};


Node.prototype.blur = function() {
        this._getDomValue(false);
    this._getDomField(false);
};


Node.prototype._duplicate = function(node) {
    var clone = node.clone();

    

    this.insertAfter(clone, node);

    return clone;
};


Node.prototype.containsNode = function(node) {
    if (this == node) {
        return true;
    }

    var childs = this.childs;
    if (childs) {
                for (var i = 0, iMax = childs.length; i < iMax; i++) {
            if (childs[i].containsNode(node)) {
                return true;
            }
        }
    }

    return false;
};


Node.prototype._move = function(node, beforeNode) {
    if (node == beforeNode) {
                return;
    }

        if (node.containsNode(this)) {
        throw new Error('Cannot move a field into a child of itself');
    }

        if (node.parent) {
        node.parent.removeChild(node);
    }

        var clone = node.clone();
    node.clearDom();

        if (beforeNode) {
        this.insertBefore(clone, beforeNode);
    }
    else {
        this.appendChild(clone);
    }

    
};


Node.prototype.removeChild = function(node) {
    if (this.childs) {
        var index = this.childs.indexOf(node);

        if (index != -1) {
            node.hide();

                        delete node.searchField;
            delete node.searchValue;

            var removedNode = this.childs.splice(index, 1)[0];

            this.updateDom({'updateIndexes': true});

            return removedNode;
        }
    }

    return undefined;
};


Node.prototype._remove = function (node) {
    this.removeChild(node);
};


Node.prototype.changeType = function (newType) {
    var oldType = this.type;

    if (oldType == newType) {
                return;
    }

    if ((newType == 'string' || newType == 'auto') &&
        (oldType == 'string' || oldType == 'auto')) {
                this.type = newType;
    }
    else {
                var table = this.dom.tr ? this.dom.tr.parentNode : undefined;
        var lastTr;
        if (this.expanded) {
            lastTr = this.getAppend();
        }
        else {
            lastTr = this.getDom();
        }
        var nextTr = (lastTr && lastTr.parentNode) ? lastTr.nextSibling : undefined;

                this.hide();
        this.clearDom();

                this.type = newType;

                if (newType == 'object') {
            if (!this.childs) {
                this.childs = [];
            }

            this.childs.forEach(function (child, index) {
                child.clearDom();
                delete child.index;
                child.fieldEditable = true;
                if (child.field == undefined) {
                    child.field = '';
                }
            });

            if (oldType == 'string' || oldType == 'auto') {
                this.expanded = true;
            }
        }
        else if (newType == 'array') {
            if (!this.childs) {
                this.childs = [];
            }

            this.childs.forEach(function (child, index) {
                child.clearDom();
                child.fieldEditable = false;
                child.index = index;
            });

            if (oldType == 'string' || oldType == 'auto') {
                this.expanded = true;
            }
        }
        else {
            this.expanded = false;
        }

                if (table) {
            if (nextTr) {
                table.insertBefore(this.getDom(), nextTr);
            }
            else {
                table.appendChild(this.getDom());
            }
        }
        this.showChilds();
    }

    if (newType == 'auto' || newType == 'string') {
                if (newType == 'string') {
            this.value = String(this.value);
        }
        else {
            this.value = this._stringCast(String(this.value));
        }

        this.focus();
    }

    this.updateDom({'updateIndexes': true});
};


Node.prototype._getDomValue = function(silent) {
    if (this.dom.value && this.type != 'array' && this.type != 'object') {
        this.valueInnerText = util.getInnerText(this.dom.value);
    }

    if (this.valueInnerText != undefined) {
        try {
                        var value;
            if (this.type == 'string') {
                value = this._unescapeHTML(this.valueInnerText);
            }
            else {
                var str = this._unescapeHTML(this.valueInnerText);
                value = this._stringCast(str);
            }
            if (value !== this.value) {
                var oldValue = this.value;
                this.value = value;
                this.editor._onAction('editValue', {
                    'node': this,
                    'oldValue': oldValue,
                    'newValue': value,
                    'oldSelection': this.editor.selection,
                    'newSelection': this.editor.getSelection()
                });
            }
        }
        catch (err) {
            this.value = undefined;
                        if (silent != true) {
                throw err;
            }
        }
    }
};


Node.prototype._updateDomValue = function () {
    var domValue = this.dom.value;
    if (domValue) {
                        var v = this.value;
        var t = (this.type == 'auto') ? typeof(v) : this.type;
        var isUrl = (t == 'string' && util.isUrl(v));
        var color = '';
        if (isUrl && !this.editor.mode.edit) {
            color = '';
        }
        else if (t == 'string') {
            color = 'green';
        }
        else if (t == 'number') {
            color = 'red';
        }
        else if (t == 'boolean') {
            color = 'orange';
        }
        else if (this._hasChilds()) {
                        color = '';
        }
        else if (v === null) {
            color = '#004ED0';          }
        else {
                        color = 'black';
        }
        domValue.style.color = color;

                var isEmpty = (String(this.value) == '' && this.type != 'array' && this.type != 'object');
        if (isEmpty) {
            util.addClassName(domValue, 'empty');
        }
        else {
            util.removeClassName(domValue, 'empty');
        }

                if (isUrl) {
            util.addClassName(domValue, 'url');
        }
        else {
            util.removeClassName(domValue, 'url');
        }

                if (t == 'array' || t == 'object') {
            var count = this.childs ? this.childs.length : 0;
            domValue.title = this.type + ' containing ' + count + ' items';
        }
        else if (t == 'string' && util.isUrl(v)) {
            if (this.editor.mode.edit) {
                domValue.title = 'Ctrl+Click or Ctrl+Enter to open url in new window';
            }
        }
        else {
            domValue.title = '';
        }

                if (this.searchValueActive) {
            util.addClassName(domValue, 'highlight-active');
        }
        else {
            util.removeClassName(domValue, 'highlight-active');
        }
        if (this.searchValue) {
            util.addClassName(domValue, 'highlight');
        }
        else {
            util.removeClassName(domValue, 'highlight');
        }

                util.stripFormatting(domValue);
    }
};


Node.prototype._updateDomField = function () {
    var domField = this.dom.field;
    if (domField) {
                var isEmpty = (String(this.field) == '' && this.parent.type != 'array');
        if (isEmpty) {
            util.addClassName(domField, 'empty');
        }
        else {
            util.removeClassName(domField, 'empty');
        }

                if (this.searchFieldActive) {
            util.addClassName(domField, 'highlight-active');
        }
        else {
            util.removeClassName(domField, 'highlight-active');
        }
        if (this.searchField) {
            util.addClassName(domField, 'highlight');
        }
        else {
            util.removeClassName(domField, 'highlight');
        }

                util.stripFormatting(domField);
    }
};


Node.prototype._getDomField = function(silent) {
    if (this.dom.field && this.fieldEditable) {
        this.fieldInnerText = util.getInnerText(this.dom.field);
    }

    if (this.fieldInnerText != undefined) {
        try {
            var field = this._unescapeHTML(this.fieldInnerText);

            if (field !== this.field) {
                var oldField = this.field;
                this.field = field;
                this.editor._onAction('editField', {
                    'node': this,
                    'oldValue': oldField,
                    'newValue': field,
                    'oldSelection': this.editor.selection,
                    'newSelection': this.editor.getSelection()
                });
            }
        }
        catch (err) {
            this.field = undefined;
                        if (silent != true) {
                throw err;
            }
        }
    }
};


Node.prototype.clearDom = function() {
            
    this.dom = {};
};


Node.prototype.getDom = function() {
    var dom = this.dom;
    if (dom.tr) {
        return dom.tr;
    }

        dom.tr = document.createElement('tr');
    dom.tr.node = this;

    if (this.editor.mode.edit) {
                var tdDrag = document.createElement('td');
        if (this.parent) {
            var domDrag = document.createElement('button');
            dom.drag = domDrag;
            domDrag.className = 'dragarea';
            domDrag.title = 'Drag to move this field (Alt+Shift+Arrows)';
            tdDrag.appendChild(domDrag);
        }
        dom.tr.appendChild(tdDrag);

                var tdMenu = document.createElement('td');
        var menu = document.createElement('button');
        dom.menu = menu;
        menu.className = 'contextmenu';
        menu.title = 'Click to open the actions menu (Ctrl+M)';
        tdMenu.appendChild(dom.menu);
        dom.tr.appendChild(tdMenu);
    }

        var tdField = document.createElement('td');
    dom.tr.appendChild(tdField);
    dom.tree = this._createDomTree();
    tdField.appendChild(dom.tree);

    this.updateDom({'updateIndexes': true});

    return dom.tr;
};


Node.prototype._onDragStart = function (event) {
    event = event || window.event;

    var node = this;
    if (!this.mousemove) {
        this.mousemove = util.addEventListener(document, 'mousemove',
            function (event) {
                node._onDrag(event);
            });
    }

    if (!this.mouseup) {
        this.mouseup = util.addEventListener(document, 'mouseup',
            function (event ) {
                node._onDragEnd(event);
            });
    }

    this.editor.highlighter.lock();
    this.drag = {
        'oldCursor': document.body.style.cursor,
        'startParent': this.parent,
        'startIndex': this.parent.childs.indexOf(this),
        'mouseX': util.getMouseX(event),
        'level': this.getLevel()
    };
    document.body.style.cursor = 'move';

    util.preventDefault(event);
};


Node.prototype._onDrag = function (event) {
        event = event || window.event;
    var mouseY = util.getMouseY(event);
    var mouseX = util.getMouseX(event);

    var trThis, trPrev, trNext, trFirst, trLast, trRoot;
    var nodePrev, nodeNext;
    var topThis, topPrev, topFirst, heightThis, bottomNext, heightNext;
    var moved = false;

    
        trThis = this.dom.tr;
    topThis = util.getAbsoluteTop(trThis);
    heightThis = trThis.offsetHeight;
    if (mouseY < topThis) {
                trPrev = trThis;
        do {
            trPrev = trPrev.previousSibling;
            nodePrev = Node.getNodeFromTarget(trPrev);
            topPrev = trPrev ? util.getAbsoluteTop(trPrev) : 0;
        }
        while (trPrev && mouseY < topPrev);

        if (nodePrev && !nodePrev.parent) {
            nodePrev = undefined;
        }

        if (!nodePrev) {
                        trRoot = trThis.parentNode.firstChild;
            trPrev = trRoot ? trRoot.nextSibling : undefined;
            nodePrev = Node.getNodeFromTarget(trPrev);
            if (nodePrev == this) {
                nodePrev = undefined;
            }
        }

        if (nodePrev) {
                        trPrev = nodePrev.dom.tr;
            topPrev = trPrev ? util.getAbsoluteTop(trPrev) : 0;
            if (mouseY > topPrev + heightThis) {
                nodePrev = undefined;
            }
        }

        if (nodePrev) {
            nodePrev.parent.moveBefore(this, nodePrev);
            moved = true;
        }
    }
    else {
                trLast = (this.expanded && this.append) ? this.append.getDom() : this.dom.tr;
        trFirst = trLast ? trLast.nextSibling : undefined;
        if (trFirst) {
            topFirst = util.getAbsoluteTop(trFirst);
            trNext = trFirst;
            do {
                nodeNext = Node.getNodeFromTarget(trNext);
                if (trNext) {
                    bottomNext = trNext.nextSibling ?
                        util.getAbsoluteTop(trNext.nextSibling) : 0;
                    heightNext = trNext ? (bottomNext - topFirst) : 0;

                    if (nodeNext.parent.childs.length == 1 && nodeNext.parent.childs[0] == this) {
                                                                        topThis += 24 - 1;
                                            }
                }

                trNext = trNext.nextSibling;
            }
            while (trNext && mouseY > topThis + heightNext);

            if (nodeNext && nodeNext.parent) {
                                var diffX = (mouseX - this.drag.mouseX);
                var diffLevel = Math.round(diffX / 24 / 2);
                var level = this.drag.level + diffLevel;                 var levelNext = nodeNext.getLevel();     
                                trPrev = nodeNext.dom.tr.previousSibling;
                while (levelNext < level && trPrev) {
                    nodePrev = Node.getNodeFromTarget(trPrev);
                    if (nodePrev == this || nodePrev._isChildOf(this)) {
                                            }
                    else if (nodePrev instanceof AppendNode) {
                        var childs = nodePrev.parent.childs;
                        if (childs.length > 1 ||
                            (childs.length == 1 && childs[0] != this)) {
                                                                                                                                            nodeNext = Node.getNodeFromTarget(trPrev);
                            levelNext = nodeNext.getLevel();
                        }
                        else {
                            break;
                        }
                    }
                    else {
                        break;
                    }

                    trPrev = trPrev.previousSibling;
                }

                                if (trLast.nextSibling != nodeNext.dom.tr) {
                    nodeNext.parent.moveBefore(this, nodeNext);
                    moved = true;
                }
            }
        }
    }

    if (moved) {
                this.drag.mouseX = mouseX;
        this.drag.level = this.getLevel();
    }

        this.editor.startAutoScroll(mouseY);

    util.preventDefault(event);
};


Node.prototype._onDragEnd = function (event) {
    event = event || window.event;

    var params = {
        'node': this,
        'startParent': this.drag.startParent,
        'startIndex': this.drag.startIndex,
        'endParent': this.parent,
        'endIndex': this.parent.childs.indexOf(this)
    };
    if ((params.startParent != params.endParent) ||
        (params.startIndex != params.endIndex)) {
                this.editor._onAction('moveNode', params);
    }

    document.body.style.cursor = this.drag.oldCursor;
    this.editor.highlighter.unlock();
    delete this.drag;

    if (this.mousemove) {
        util.removeEventListener(document, 'mousemove', this.mousemove);
        delete this.mousemove;}
    if (this.mouseup) {
        util.removeEventListener(document, 'mouseup', this.mouseup);
        delete this.mouseup;
    }

        this.editor.stopAutoScroll();

    util.preventDefault(event);
};


Node.prototype._isChildOf = function (node) {
    var n = this.parent;
    while (n) {
        if (n == node) {
            return true;
        }
        n = n.parent;
    }

    return false;
};


Node.prototype._createDomField = function () {
    return document.createElement('div');
};


Node.prototype.setHighlight = function (highlight) {
    if (this.dom.tr) {
        this.dom.tr.className = (highlight ? 'highlight' : '');

        if (this.append) {
            this.append.setHighlight(highlight);
        }

        if (this.childs) {
            this.childs.forEach(function (child) {
                child.setHighlight(highlight);
            });
        }
    }
};


Node.prototype.updateValue = function (value) {
    this.value = value;
    this.updateDom();
};


Node.prototype.updateField = function (field) {
    this.field = field;
    this.updateDom();
};


Node.prototype.updateDom = function (options) {
        var domTree = this.dom.tree;
    if (domTree) {
        domTree.style.marginLeft = this.getLevel() * 24 + 'px';
    }

        var domField = this.dom.field;
    if (domField) {
        if (this.fieldEditable == true) {
                        domField.contentEditable = this.editor.mode.edit;
            domField.spellcheck = false;
            domField.className = 'field';
        }
        else {
                        domField.className = 'readonly';
        }

        var field;
        if (this.index != undefined) {
            field = this.index;
        }
        else if (this.field != undefined) {
            field = this.field;
        }
        else if (this._hasChilds()) {
            field = this.type;
        }
        else {
            field = '';
        }
        domField.innerHTML = this._escapeHTML(field);
    }

        var domValue = this.dom.value;
    if (domValue) {
        var count = this.childs ? this.childs.length : 0;
        if (this.type == 'array') {
            domValue.innerHTML = '[' + count + ']';
        }
        else if (this.type == 'object') {
            domValue.innerHTML = '{' + count + '}';
        }
        else {
            domValue.innerHTML = this._escapeHTML(this.value);
        }
    }

        this._updateDomField();
    this._updateDomValue();

        if (options && options.updateIndexes == true) {
                this._updateDomIndexes();
    }

    if (options && options.recurse == true) {
                if (this.childs) {
            this.childs.forEach(function (child) {
                child.updateDom(options);
            });
        }
    }

        if (this.append) {
        this.append.updateDom();
    }
};


Node.prototype._updateDomIndexes = function () {
    var domValue = this.dom.value;
    var childs = this.childs;
    if (domValue && childs) {
        if (this.type == 'array') {
            childs.forEach(function (child, index) {
                child.index = index;
                var childField = child.dom.field;
                if (childField) {
                    childField.innerHTML = index;
                }
            });
        }
        else if (this.type == 'object') {
            childs.forEach(function (child) {
                if (child.index != undefined) {
                    delete child.index;

                    if (child.field == undefined) {
                        child.field = '';
                    }
                }
            });
        }
    }
};


Node.prototype._createDomValue = function () {
    var domValue;

    if (this.type == 'array') {
        domValue = document.createElement('div');
        domValue.className = 'readonly';
        domValue.innerHTML = '[...]';
    }
    else if (this.type == 'object') {
        domValue = document.createElement('div');
        domValue.className = 'readonly';
        domValue.innerHTML = '{...}';
    }
    else {
        if (!this.editor.mode.edit && util.isUrl(this.value)) {
                        domValue = document.createElement('a');
            domValue.className = 'value';
            domValue.href = this.value;
            domValue.target = '_blank';
            domValue.innerHTML = this._escapeHTML(this.value);
        }
        else {
                        domValue = document.createElement('div');
            domValue.contentEditable = !this.editor.mode.view;
            domValue.spellcheck = false;
            domValue.className = 'value';
            domValue.innerHTML = this._escapeHTML(this.value);
        }
    }

    return domValue;
};


Node.prototype._createDomExpandButton = function () {
        var expand = document.createElement('button');
    if (this._hasChilds()) {
        expand.className = this.expanded ? 'expanded' : 'collapsed';
        expand.title =
            'Click to expand/collapse this field (Ctrl+E). \n' +
                'Ctrl+Click to expand/collapse including all childs.';
    }
    else {
        expand.className = 'invisible';
        expand.title = '';
    }

    return expand;
};



Node.prototype._createDomTree = function () {
    var dom = this.dom;
    var domTree = document.createElement('table');
    var tbody = document.createElement('tbody');
    domTree.style.borderCollapse = 'collapse';     domTree.appendChild(tbody);
    var tr = document.createElement('tr');
    tbody.appendChild(tr);

        var tdExpand = document.createElement('td');
    tdExpand.className = 'tree';
    tr.appendChild(tdExpand);
    dom.expand = this._createDomExpandButton();
    tdExpand.appendChild(dom.expand);
    dom.tdExpand = tdExpand;

        var tdField = document.createElement('td');
    tdField.className = 'tree';
    tr.appendChild(tdField);
    dom.field = this._createDomField();
    tdField.appendChild(dom.field);
    dom.tdField = tdField;

        var tdSeparator = document.createElement('td');
    tdSeparator.className = 'tree';
    tr.appendChild(tdSeparator);
    if (this.type != 'object' && this.type != 'array') {
        tdSeparator.appendChild(document.createTextNode(':'));
        tdSeparator.className = 'separator';
    }
    dom.tdSeparator = tdSeparator;

        var tdValue = document.createElement('td');
    tdValue.className = 'tree';
    tr.appendChild(tdValue);
    dom.value = this._createDomValue();
    tdValue.appendChild(dom.value);
    dom.tdValue = tdValue;

    return domTree;
};


Node.prototype.onEvent = function (event) {
    var type = event.type,
        target = event.target || event.srcElement,
        dom = this.dom,
        node = this,
        focusNode,
        expandable = this._hasChilds();

            if (target == dom.drag || target == dom.menu) {
        if (type == 'mouseover') {
            this.editor.highlighter.highlight(this);
        }
        else if (type == 'mouseout') {
            this.editor.highlighter.unhighlight();
        }
    }

        if (type == 'mousedown' && target == dom.drag) {
        this._onDragStart(event);
    }

        if (type == 'click' && target == dom.menu) {
        var highlighter = node.editor.highlighter;
        highlighter.highlight(node);
        highlighter.lock();
        util.addClassName(dom.menu, 'selected');
        this.showContextMenu(dom.menu, function () {
            util.removeClassName(dom.menu, 'selected');
            highlighter.unlock();
            highlighter.unhighlight();
        });
    }

        if (type == 'click' && target == dom.expand) {
        if (expandable) {
            var recurse = event.ctrlKey;             this._onExpand(recurse);
        }
    }

        var domValue = dom.value;
    if (target == domValue) {
                switch (type) {
            case 'focus':
                focusNode = this;
                break;

            case 'blur':
            case 'change':
                this._getDomValue(true);
                this._updateDomValue();
                if (this.value) {
                    domValue.innerHTML = this._escapeHTML(this.value);
                }
                break;

            case 'input':
                this._getDomValue(true);
                this._updateDomValue();
                break;

            case 'keydown':
            case 'mousedown':
                this.editor.selection = this.editor.getSelection();
                break;

            case 'click':
                if (event.ctrlKey && this.editor.mode.edit) {
                    if (util.isUrl(this.value)) {
                        window.open(this.value, '_blank');
                    }
                }
                break;

            case 'keyup':
                this._getDomValue(true);
                this._updateDomValue();
                break;

            case 'cut':
            case 'paste':
                setTimeout(function () {
                    node._getDomValue(true);
                    node._updateDomValue();
                }, 1);
                break;
        }
    }

        var domField = dom.field;
    if (target == domField) {
        switch (type) {
            case 'focus':
                focusNode = this;
                break;

            case 'blur':
            case 'change':
                this._getDomField(true);
                this._updateDomField();
                if (this.field) {
                    domField.innerHTML = this._escapeHTML(this.field);
                }
                break;

            case 'input':
                this._getDomField(true);
                this._updateDomField();
                break;

            case 'keydown':
            case 'mousedown':
                this.editor.selection = this.editor.getSelection();
                break;

            case 'keyup':
                this._getDomField(true);
                this._updateDomField();
                break;

            case 'cut':
            case 'paste':
                setTimeout(function () {
                    node._getDomField(true);
                    node._updateDomField();
                }, 1);
                break;
        }
    }

            var domTree = dom.tree;
    if (target == domTree.parentNode) {
        switch (type) {
            case 'click':
                var left = (event.offsetX != undefined) ?
                    (event.offsetX < (this.getLevel() + 1) * 24) :
                    (util.getMouseX(event) < util.getAbsoluteLeft(dom.tdSeparator));                if (left || expandable) {
                                        if (domField) {
                        util.setEndOfContentEditable(domField);
                        domField.focus();
                    }
                }
                else {
                    if (domValue) {
                        util.setEndOfContentEditable(domValue);
                        domValue.focus();
                    }
                }
                break;
        }
    }
    if ((target == dom.tdExpand && !expandable) || target == dom.tdField ||
        target == dom.tdSeparator) {
        switch (type) {
            case 'click':
                if (domField) {
                    util.setEndOfContentEditable(domField);
                    domField.focus();
                }
                break;
        }
    }

    if (type == 'keydown') {
        this.onKeyDown(event);
    }
};


Node.prototype.onKeyDown = function (event) {
    var keynum = event.which || event.keyCode;
    var target = event.target || event.srcElement;
    var ctrlKey = event.ctrlKey;
    var shiftKey = event.shiftKey;
    var altKey = event.altKey;
    var handled = false;
    var prevNode, nextNode, nextDom, nextDom2;

        if (keynum == 13) {         if (target == this.dom.value) {
            if (!this.editor.mode.edit || event.ctrlKey) {
                if (util.isUrl(this.value)) {
                    window.open(this.value, '_blank');
                    handled = true;
                }
            }
        }
        else if (target == this.dom.expand) {
            var expandable = this._hasChilds();
            if (expandable) {
                var recurse = event.ctrlKey;                 this._onExpand(recurse);
                target.focus();
                handled = true;
            }
        }
    }
    else if (keynum == 68) {          if (ctrlKey) {               this._onDuplicate();
            handled = true;
        }
    }
    else if (keynum == 69) {         if (ctrlKey) {                   this._onExpand(shiftKey);              target.focus();             handled = true;
        }
    }
    else if (keynum == 77) {         if (ctrlKey) {             this.showContextMenu(target);
            handled = true;
        }
    }
    else if (keynum == 46) {         if (ctrlKey) {                   this._onRemove();
            handled = true;
        }
    }
    else if (keynum == 45) {         if (ctrlKey && !shiftKey) {                   this._onInsertBefore();
            handled = true;
        }
        else if (ctrlKey && shiftKey) {               this._onInsertAfter();
            handled = true;
        }
    }
    else if (keynum == 35) {         if (altKey) {                         var lastNode = this._lastNode();
            if (lastNode) {
                lastNode.focus(Node.focusElement || this._getElementName(target));
            }
            handled = true;
        }
    }
    else if (keynum == 36) {         if (altKey) {                         var firstNode = this._firstNode();
            if (firstNode) {
                firstNode.focus(Node.focusElement || this._getElementName(target));
            }
            handled = true;
        }
    }
    else if (keynum == 37) {                if (altKey && !shiftKey) {                          var prevElement = this._previousElement(target);
            if (prevElement) {
                this.focus(this._getElementName(prevElement));
            }
            handled = true;
        }
        else if (altKey && shiftKey) {             if (this.expanded) {
                var appendDom = this.getAppend();
                nextDom = appendDom ? appendDom.nextSibling : undefined;
            }
            else {
                var dom = this.getDom();
                nextDom = dom.nextSibling;
            }
            if (nextDom) {
                nextNode = Node.getNodeFromTarget(nextDom);
                nextDom2 = nextDom.nextSibling;
                nextNode2 = Node.getNodeFromTarget(nextDom2);
                if (nextNode && nextNode instanceof AppendNode &&
                        !(this.parent.childs.length == 1) &&
                        nextNode2 && nextNode2.parent) {
                    nextNode2.parent.moveBefore(this, nextNode2);
                    this.focus(Node.focusElement || this._getElementName(target));
                }
            }
        }
    }
    else if (keynum == 38) {                if (altKey && !shiftKey) {                          prevNode = this._previousNode();
            if (prevNode) {
                prevNode.focus(Node.focusElement || this._getElementName(target));
            }
            handled = true;
        }
        else if (altKey && shiftKey) {                         prevNode = this._previousNode();
            if (prevNode && prevNode.parent) {
                prevNode.parent.moveBefore(this, prevNode);
                this.focus(Node.focusElement || this._getElementName(target));
            }
            handled = true;
        }
    }
    else if (keynum == 39) {                if (altKey && !shiftKey) {                          var nextElement = this._nextElement(target);
            if (nextElement) {
                this.focus(this._getElementName(nextElement));
            }
            handled = true;
        }
        else if (altKey && shiftKey) {             dom = this.getDom();
            var prevDom = dom.previousSibling;
            if (prevDom) {
                prevNode = Node.getNodeFromTarget(prevDom);
                if (prevNode && prevNode.parent &&
                        (prevNode instanceof AppendNode)
                        && !prevNode.isVisible()) {
                    prevNode.parent.moveBefore(this, prevNode);
                    this.focus(Node.focusElement || this._getElementName(target));
                }
            }
        }
    }
    else if (keynum == 40) {                if (altKey && !shiftKey) {                          nextNode = this._nextNode();
            if (nextNode) {
                nextNode.focus(Node.focusElement || this._getElementName(target));
            }
            handled = true;
        }
        else if (altKey && shiftKey) {                         if (this.expanded) {
                nextNode = this.append ? this.append._nextNode() : undefined;
            }
            else {
                nextNode = this._nextNode();
            }
            nextDom = nextNode ? nextNode.getDom() : undefined;
            if (this.parent.childs.length == 1) {
                nextDom2 = nextDom;
            }
            else {
                nextDom2 = nextDom ? nextDom.nextSibling : undefined;
            }
            var nextNode2 = Node.getNodeFromTarget(nextDom2);
            if (nextNode2 && nextNode2.parent) {
                nextNode2.parent.moveBefore(this, nextNode2);
                this.focus(Node.focusElement || this._getElementName(target));
            }
            handled = true;
        }
    }

    if (handled) {
        util.preventDefault(event);
        util.stopPropagation(event);
    }
};


Node.prototype._onExpand = function (recurse) {
    if (recurse) {
                var table = this.dom.tr.parentNode;         var frame = table.parentNode;
        var scrollTop = frame.scrollTop;
        frame.removeChild(table);
    }

    if (this.expanded) {
        this.collapse(recurse);
    }
    else {
        this.expand(recurse);
    }

    if (recurse) {
                frame.appendChild(table);
        frame.scrollTop = scrollTop;
    }
};


Node.prototype._onRemove = function() {
    this.editor.highlighter.unhighlight();
    var childs = this.parent.childs;
    var index = childs.indexOf(this);

        var oldSelection = this.editor.getSelection();
    if (childs[index + 1]) {
        childs[index + 1].focus();
    }
    else if (childs[index - 1]) {
        childs[index - 1].focus();
    }
    else {
        this.parent.focus();
    }
    var newSelection = this.editor.getSelection();

        this.parent._remove(this);

        this.editor._onAction('removeNode', {
        'node': this,
        'parent': this.parent,
        'index': index,
        'oldSelection': oldSelection,
        'newSelection': newSelection
    });
};


Node.prototype._onDuplicate = function() {
    var oldSelection = this.editor.getSelection();
    var clone = this.parent._duplicate(this);
    clone.focus();
    var newSelection = this.editor.getSelection();

    this.editor._onAction('duplicateNode', {
        'node': this,
        'clone': clone,
        'parent': this.parent,
        'oldSelection': oldSelection,
        'newSelection': newSelection
    });
};


Node.prototype._onInsertBefore = function (field, value, type) {
    var oldSelection = this.editor.getSelection();

    var newNode = new Node(this.editor, {
        'field': (field != undefined) ? field : '',
        'value': (value != undefined) ? value : '',
        'type': type
    });
    newNode.expand(true);
    this.parent.insertBefore(newNode, this);
    this.editor.highlighter.unhighlight();
    newNode.focus('field');
    var newSelection = this.editor.getSelection();

    this.editor._onAction('insertBeforeNode', {
        'node': newNode,
        'beforeNode': this,
        'parent': this.parent,
        'oldSelection': oldSelection,
        'newSelection': newSelection
    });
};


Node.prototype._onInsertAfter = function (field, value, type) {
    var oldSelection = this.editor.getSelection();

    var newNode = new Node(this.editor, {
        'field': (field != undefined) ? field : '',
        'value': (value != undefined) ? value : '',
        'type': type
    });
    newNode.expand(true);
    this.parent.insertAfter(newNode, this);
    this.editor.highlighter.unhighlight();
    newNode.focus('field');
    var newSelection = this.editor.getSelection();

    this.editor._onAction('insertAfterNode', {
        'node': newNode,
        'afterNode': this,
        'parent': this.parent,
        'oldSelection': oldSelection,
        'newSelection': newSelection
    });
};


Node.prototype._onAppend = function (field, value, type) {
    var oldSelection = this.editor.getSelection();

    var newNode = new Node(this.editor, {
        'field': (field != undefined) ? field : '',
        'value': (value != undefined) ? value : '',
        'type': type
    });
    newNode.expand(true);
    this.parent.appendChild(newNode);
    this.editor.highlighter.unhighlight();
    newNode.focus('field');
    var newSelection = this.editor.getSelection();

    this.editor._onAction('appendNode', {
        'node': newNode,
        'parent': this.parent,
        'oldSelection': oldSelection,
        'newSelection': newSelection
    });
};


Node.prototype._onChangeType = function (newType) {
    var oldType = this.type;
    if (newType != oldType) {
        var oldSelection = this.editor.getSelection();
        this.changeType(newType);
        var newSelection = this.editor.getSelection();

        this.editor._onAction('changeType', {
            'node': this,
            'oldType': oldType,
            'newType': newType,
            'oldSelection': oldSelection,
            'newSelection': newSelection
        });
    }
};


Node.prototype._onSort = function (direction) {
    if (this._hasChilds()) {
        var order = (direction == 'desc') ? -1 : 1;
        var prop = (this.type == 'array') ? 'value': 'field';
        this.hideChilds();

        var oldChilds = this.childs;
        var oldSort = this.sort;

                this.childs = this.childs.concat();

                this.childs.sort(function (a, b) {
            if (a[prop] > b[prop]) return order;
            if (a[prop] < b[prop]) return -order;
            return 0;
        });
        this.sort = (order == 1) ? 'asc' : 'desc';

        this.editor._onAction('sort', {
            'node': this,
            'oldChilds': oldChilds,
            'oldSort': oldSort,
            'newChilds': this.childs,
            'newSort': this.sort
        });

        this.showChilds();
    }
};


Node.prototype.getAppend = function () {
    if (!this.append) {
        this.append = new AppendNode(this.editor);
        this.append.setParent(this);
    }
    return this.append.getDom();
};


Node.getNodeFromTarget = function (target) {
    while (target) {
        if (target.node) {
            return target.node;
        }
        target = target.parentNode;
    }

    return undefined;
};


Node.prototype._previousNode = function () {
    var prevNode = null;
    var dom = this.getDom();
    if (dom && dom.parentNode) {
                var prevDom = dom;
        do {
            prevDom = prevDom.previousSibling;
            prevNode = Node.getNodeFromTarget(prevDom);
        }
        while (prevDom && (prevNode instanceof AppendNode && !prevNode.isVisible()));
    }
    return prevNode;
};


Node.prototype._nextNode = function () {
    var nextNode = null;
    var dom = this.getDom();
    if (dom && dom.parentNode) {
                var nextDom = dom;
        do {
            nextDom = nextDom.nextSibling;
            nextNode = Node.getNodeFromTarget(nextDom);
        }
        while (nextDom && (nextNode instanceof AppendNode && !nextNode.isVisible()));
    }

    return nextNode;
};


Node.prototype._firstNode = function () {
    var firstNode = null;
    var dom = this.getDom();
    if (dom && dom.parentNode) {
        var firstDom = dom.parentNode.firstChild;
        firstNode = Node.getNodeFromTarget(firstDom);
    }

    return firstNode;
};


Node.prototype._lastNode = function () {
    var lastNode = null;
    var dom = this.getDom();
    if (dom && dom.parentNode) {
        var lastDom = dom.parentNode.lastChild;
        lastNode =  Node.getNodeFromTarget(lastDom);
        while (lastDom && (lastNode instanceof AppendNode && !lastNode.isVisible())) {
            lastDom = lastDom.previousSibling;
            lastNode =  Node.getNodeFromTarget(lastDom);
        }
    }
    return lastNode;
};


Node.prototype._previousElement = function (elem) {
    var dom = this.dom;
        switch (elem) {
        case dom.value:
            if (this.fieldEditable) {
                return dom.field;
            }
                case dom.field:
            if (this._hasChilds()) {
                return dom.expand;
            }
                case dom.expand:
            return dom.menu;
        case dom.menu:
            if (dom.drag) {
                return dom.drag;
            }
                default:
            return null;
    }
};


Node.prototype._nextElement = function (elem) {
    var dom = this.dom;
        switch (elem) {
        case dom.drag:
            return dom.menu;
        case dom.menu:
            if (this._hasChilds()) {
                return dom.expand;
            }
                case dom.expand:
            if (this.fieldEditable) {
                return dom.field;
            }
                case dom.field:
            if (!this._hasChilds()) {
                return dom.value;
            }
        default:
            return null;
    }
};


Node.prototype._getElementName = function (element) {
    var dom = this.dom;
    for (var name in dom) {
        if (dom.hasOwnProperty(name)) {
            if (dom[name] == element) {
                return name;
            }
        }
    }
    return null;
};


Node.prototype._hasChilds = function () {
    return this.type == 'array' || this.type == 'object';
};

Node.TYPE_TITLES = {
    'auto': 'Field type "auto". ' +
        'The field type is automatically determined from the value ' +
        'and can be a string, number, boolean, or null.',
    'object': 'Field type "object". ' +
        'An object contains an unordered set of key/value pairs.',
    'array': 'Field type "array". ' +
        'An array contains an ordered collection of values.',
    'string': 'Field type "string". ' +
        'Field type is not determined from the value, ' +
        'but always returned as string.'
};


Node.prototype.showContextMenu = function (anchor, onClose) {
    var node = this;
    var titles = Node.TYPE_TITLES;
    var items = [];

    items.push({
        'text': 'Type',
        'title': 'Change the type of this field',
        'className': 'type-' + this.type,
        'submenu': [
            {
                'text': 'Auto',
                'className': 'type-auto' +
                    (this.type == 'auto' ? ' selected' : ''),
                'title': titles.auto,
                'click': function () {
                    node._onChangeType('auto');
                }
            },
            {
                'text': 'Array',
                'className': 'type-array' +
                    (this.type == 'array' ? ' selected' : ''),
                'title': titles.array,
                'click': function () {
                    node._onChangeType('array');
                }
            },
            {
                'text': 'Object',
                'className': 'type-object' +
                    (this.type == 'object' ? ' selected' : ''),
                'title': titles.object,
                'click': function () {
                    node._onChangeType('object');
                }
            },
            {
                'text': 'String',
                'className': 'type-string' +
                    (this.type == 'string' ? ' selected' : ''),
                'title': titles.string,
                'click': function () {
                    node._onChangeType('string');
                }
            }
        ]
    });

    if (this._hasChilds()) {
        var direction = ((this.sort == 'asc') ? 'desc': 'asc');
        items.push({
            'text': 'Sort',
            'title': 'Sort the childs of this ' + this.type,
            'className': 'sort-' + direction,
            'click': function () {
                node._onSort(direction);
            },
            'submenu': [
                {
                    'text': 'Ascending',
                    'className': 'sort-asc',
                    'title': 'Sort the childs of this ' + this.type + ' in ascending order',
                    'click': function () {
                        node._onSort('asc');
                    }
                },
                {
                    'text': 'Descending',
                    'className': 'sort-desc',
                    'title': 'Sort the childs of this ' + this.type +' in descending order',
                    'click': function () {
                        node._onSort('desc');
                    }
                }
            ]
        });
    }

    if (this.parent && this.parent._hasChilds()) {
                items.push({
            'type': 'separator'
        });

                var childs = node.parent.childs;
        if (node == childs[childs.length - 1]) {
            items.push({
                'text': 'Append',
                'title': 'Append a new field with type \'auto\' after this field (Ctrl+Shift+Ins)',
                'submenuTitle': 'Select the type of the field to be appended',
                'className': 'append',
                'click': function () {
                    node._onAppend('', '', 'auto');
                },
                'submenu': [
                    {
                        'text': 'Auto',
                        'className': 'type-auto',
                        'title': titles.auto,
                        'click': function () {
                            node._onAppend('', '', 'auto');
                        }
                    },
                    {
                        'text': 'Array',
                        'className': 'type-array',
                        'title': titles.array,
                        'click': function () {
                            node._onAppend('', []);
                        }
                    },
                    {
                        'text': 'Object',
                        'className': 'type-object',
                        'title': titles.object,
                        'click': function () {
                            node._onAppend('', {});
                        }
                    },
                    {
                        'text': 'String',
                        'className': 'type-string',
                        'title': titles.string,
                        'click': function () {
                            node._onAppend('', '', 'string');
                        }
                    }
                ]
            });
        }

                items.push({
            'text': 'Insert',
            'title': 'Insert a new field with type \'auto\' before this field (Ctrl+Ins)',
            'submenuTitle': 'Select the type of the field to be inserted',
            'className': 'insert',
            'click': function () {
                node._onInsertBefore('', '', 'auto');
            },
            'submenu': [
                {
                    'text': 'Auto',
                    'className': 'type-auto',
                    'title': titles.auto,
                    'click': function () {
                        node._onInsertBefore('', '', 'auto');
                    }
                },
                {
                    'text': 'Array',
                    'className': 'type-array',
                    'title': titles.array,
                    'click': function () {
                        node._onInsertBefore('', []);
                    }
                },
                {
                    'text': 'Object',
                    'className': 'type-object',
                    'title': titles.object,
                    'click': function () {
                        node._onInsertBefore('', {});
                    }
                },
                {
                    'text': 'String',
                    'className': 'type-string',
                    'title': titles.string,
                    'click': function () {
                        node._onInsertBefore('', '', 'string');
                    }
                }
            ]
        });

                items.push({
            'text': 'Duplicate',
            'title': 'Duplicate this field (Ctrl+D)',
            'className': 'duplicate',
            'click': function () {
                node._onDuplicate();
            }
        });

                items.push({
            'text': 'Remove',
            'title': 'Remove this field (Ctrl+Del)',
            'className': 'remove',
            'click': function () {
                node._onRemove();
            }
        });
    }

    var menu = new ContextMenu(items, {close: onClose});
    menu.show(anchor);
};


Node.prototype._getType = function(value) {
    if (value instanceof Array) {
        return 'array';
    }
    if (value instanceof Object) {
        return 'object';
    }
    if (typeof(value) == 'string' && typeof(this._stringCast(value)) != 'string') {
        return 'string';
    }

    return 'auto';
};


Node.prototype._stringCast = function(str) {
    var lower = str.toLowerCase(),
        num = Number(str),                  numFloat = parseFloat(str); 
    if (str == '') {
        return '';
    }
    else if (lower == 'null') {
        return null;
    }
    else if (lower == 'true') {
        return true;
    }
    else if (lower == 'false') {
        return false;
    }
    else if (!isNaN(num) && !isNaN(numFloat)) {
        return num;
    }
    else {
        return str;
    }
};


Node.prototype._escapeHTML = function (text) {
    var htmlEscaped = String(text)
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/  /g, ' &nbsp;')         .replace(/^ /, '&nbsp;')           .replace(/ $/, '&nbsp;');  
    var json = JSON.stringify(htmlEscaped);
    return json.substring(1, json.length - 1);
};


Node.prototype._unescapeHTML = function (escapedText) {
    var json = '"' + this._escapeJSON(escapedText) + '"';
    var htmlEscaped = util.parse(json);
    return htmlEscaped
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&nbsp;/g, ' ');
};


Node.prototype._escapeJSON = function (text) {
        var escaped = '';
    var i = 0, iMax = text.length;
    while (i < iMax) {
        var c = text.charAt(i);
        if (c == '\n') {
            escaped += '\\n';
        }
        else if (c == '\\') {
            escaped += c;
            i++;

            c = text.charAt(i);
            if ('"\\/bfnrtu'.indexOf(c) == -1) {
                escaped += '\\';              }
            escaped += c;
        }
        else if (c == '"') {
            escaped += '\\"';
        }
        else {
            escaped += c;
        }
        i++;
    }

    return escaped;
};


function AppendNode (editor) {
    
    this.editor = editor;
    this.dom = {};
}

AppendNode.prototype = new Node();


AppendNode.prototype.getDom = function () {
        var dom = this.dom;

    if (dom.tr) {
        return dom.tr;
    }

        var trAppend = document.createElement('tr');
    trAppend.node = this;
    dom.tr = trAppend;

    
    if (this.editor.mode.edit) {
                dom.tdDrag = document.createElement('td');

                var tdMenu = document.createElement('td');
        dom.tdMenu = tdMenu;
        var menu = document.createElement('button');
        menu.className = 'contextmenu';
        menu.title = 'Click to open the actions menu (Ctrl+M)';
        dom.menu = menu;
        tdMenu.appendChild(dom.menu);
    }

        var tdAppend = document.createElement('td');
    var domText = document.createElement('div');
    domText.innerHTML = '(empty)';
    domText.className = 'readonly';
    tdAppend.appendChild(domText);
    dom.td = tdAppend;
    dom.text = domText;

    this.updateDom();

    return trAppend;
};


AppendNode.prototype.updateDom = function () {
    var dom = this.dom;
    var tdAppend = dom.td;
    if (tdAppend) {
        tdAppend.style.paddingLeft = (this.getLevel() * 24 + 26) + 'px';
            }

    var domText = dom.text;
    if (domText) {
        domText.innerHTML = '(empty ' + this.parent.type + ')';
    }

            var trAppend = dom.tr;
    if (!this.isVisible()) {
        if (dom.tr.firstChild) {
            if (dom.tdDrag) {
                trAppend.removeChild(dom.tdDrag);
            }
            if (dom.tdMenu) {
                trAppend.removeChild(dom.tdMenu);
            }
            trAppend.removeChild(tdAppend);
        }
    }
    else {
        if (!dom.tr.firstChild) {
            if (dom.tdDrag) {
                trAppend.appendChild(dom.tdDrag);
            }
            if (dom.tdMenu) {
                trAppend.appendChild(dom.tdMenu);
            }
            trAppend.appendChild(tdAppend);
        }
    }
};


AppendNode.prototype.isVisible = function () {
    return (this.parent.childs.length == 0);
};


AppendNode.prototype.showContextMenu = function (anchor, onClose) {
    var node = this;
    var titles = Node.TYPE_TITLES;
    var items = [
                {
            'text': 'Append',
            'title': 'Append a new field with type \'auto\' (Ctrl+Shift+Ins)',
            'submenuTitle': 'Select the type of the field to be appended',
            'className': 'insert',
            'click': function () {
                node._onAppend('', '', 'auto');
            },
            'submenu': [
                {
                    'text': 'Auto',
                    'className': 'type-auto',
                    'title': titles.auto,
                    'click': function () {
                        node._onAppend('', '', 'auto');
                    }
                },
                {
                    'text': 'Array',
                    'className': 'type-array',
                    'title': titles.array,
                    'click': function () {
                        node._onAppend('', []);
                    }
                },
                {
                    'text': 'Object',
                    'className': 'type-object',
                    'title': titles.object,
                    'click': function () {
                        node._onAppend('', {});
                    }
                },
                {
                    'text': 'String',
                    'className': 'type-string',
                    'title': titles.string,
                    'click': function () {
                        node._onAppend('', '', 'string');
                    }
                }
            ]
        }
    ];

    var menu = new ContextMenu(items, {close: onClose});
    menu.show(anchor);
};


AppendNode.prototype.onEvent = function (event) {
    var type = event.type;
    var target = event.target || event.srcElement;
    var dom = this.dom;

        var menu = dom.menu;
    if (target == menu) {
        if (type == 'mouseover') {
            this.editor.highlighter.highlight(this.parent);
        }
        else if (type == 'mouseout') {
            this.editor.highlighter.unhighlight();
        }
    }

        if (type == 'click' && target == dom.menu) {
        var highlighter = this.editor.highlighter;
        highlighter.highlight(this.parent);
        highlighter.lock();
        util.addClassName(dom.menu, 'selected');
        this.showContextMenu(dom.menu, function () {
            util.removeClassName(dom.menu, 'selected');
            highlighter.unlock();
            highlighter.unhighlight();
        });
    }

    if (type == 'keydown') {
        this.onKeyDown(event);
    }
};


function ContextMenu (items, options) {
    this.dom = {};

    var me = this;
    var dom = this.dom;
    this.anchor = undefined;
    this.items = items;
    this.eventListeners = {};
    this.selection = undefined;     this.visibleSubmenu = undefined;
    this.onClose = options ? options.close : undefined;

        var menu = document.createElement('div');
    menu.className = 'jsoneditor-contextmenu';
    dom.menu = menu;

        var list = document.createElement('ul');
    list.className = 'menu';
    menu.appendChild(list);
    dom.list = list;
    dom.items = []; 
        var focusButton = document.createElement('button');
    dom.focusButton = focusButton;
    var li = document.createElement('li');
    li.style.overflow = 'hidden';
    li.style.height = '0';
    li.appendChild(focusButton);
    list.appendChild(li);

    function createMenuItems (list, domItems, items) {
        items.forEach(function (item) {
            if (item.type == 'separator') {
                                var separator = document.createElement('div');
                separator.className = 'separator';
                li = document.createElement('li');
                li.appendChild(separator);
                list.appendChild(li);
            }
            else {
                var domItem = {};

                                var li = document.createElement('li');
                list.appendChild(li);

                                var button = document.createElement('button');
                button.className = item.className;
                domItem.button = button;
                if (item.title) {
                    button.title = item.title;
                }
                if (item.click) {
                    button.onclick = function () {
                        me.hide();
                        item.click();
                    };
                }
                li.appendChild(button);

                                if (item.submenu) {
                                        var divIcon = document.createElement('div');
                    divIcon.className = 'icon';
                    button.appendChild(divIcon);
                    button.appendChild(document.createTextNode(item.text));

                    var buttonSubmenu;
                    if (item.click) {
                                                button.className += ' default';

                        var buttonExpand = document.createElement('button');
                        domItem.buttonExpand = buttonExpand;
                        buttonExpand.className = 'expand';
                        buttonExpand.innerHTML = '<div class="expand"></div>';
                        li.appendChild(buttonExpand);
                        if (item.submenuTitle) {
                            buttonExpand.title = item.submenuTitle;
                        }

                        buttonSubmenu = buttonExpand;
                    }
                    else {
                                                var divExpand = document.createElement('div');
                        divExpand.className = 'expand';
                        button.appendChild(divExpand);

                        buttonSubmenu = button;
                    }

                                        buttonSubmenu.onclick = function () {
                        me._onExpandItem(domItem);
                        buttonSubmenu.focus();
                    };

                                        var domSubItems = [];
                    domItem.subItems = domSubItems;
                    var ul = document.createElement('ul');
                    domItem.ul = ul;
                    ul.className = 'menu';
                    ul.style.height = '0';
                    li.appendChild(ul);
                    createMenuItems(ul, domSubItems, item.submenu);
                }
                else {
                                        button.innerHTML = '<div class="icon"></div>' + item.text;
                }

                domItems.push(domItem);
            }
        });
    }
    createMenuItems(list, this.dom.items, items);

    
        this.maxHeight = 0;     items.forEach(function (item) {
        var height = (items.length + (item.submenu ? item.submenu.length : 0)) * 24;
        me.maxHeight = Math.max(me.maxHeight, height);
    });
}


ContextMenu.prototype._getVisibleButtons = function () {
    var buttons = [];
    var me = this;
    this.dom.items.forEach(function (item) {
        buttons.push(item.button);
        if (item.buttonExpand) {
            buttons.push(item.buttonExpand);
        }
        if (item.subItems && item == me.expandedItem) {
            item.subItems.forEach(function (subItem) {
                buttons.push(subItem.button);
                if (subItem.buttonExpand) {
                    buttons.push(subItem.buttonExpand);
                }
                            });
        }
    });

    return buttons;
};

ContextMenu.visibleMenu = undefined;


ContextMenu.prototype.show = function (anchor) {
    this.hide();

        var windowHeight = util.getWindowHeight();
    var anchorHeight = anchor.offsetHeight;
    var menuHeight = this.maxHeight;

        var left = util.getAbsoluteLeft(anchor);
    var top = util.getAbsoluteTop(anchor);
    if (top + anchorHeight + menuHeight < windowHeight) {
                this.dom.menu.style.left = left + 'px';
        this.dom.menu.style.top = (top + anchorHeight) + 'px';
        this.dom.menu.style.bottom = '';
    }
    else {
                this.dom.menu.style.left = left + 'px';
        this.dom.menu.style.top = '';
        this.dom.menu.style.bottom = (windowHeight - top) + 'px';
    }

        document.body.appendChild(this.dom.menu);

        var me = this;
    var list = this.dom.list;
    this.eventListeners.mousedown = util.addEventListener(
        document, 'mousedown', function (event) {
                        event = event || window.event;
            var target = event.target || event.srcElement;
            if ((target != list) && !me._isChildOf(target, list)) {
                me.hide();
                util.stopPropagation(event);
                util.preventDefault(event);
            }
        });
    this.eventListeners.mousewheel = util.addEventListener(
        document, 'mousewheel', function () {
                        util.stopPropagation(event);
            util.preventDefault(event);
        });
    this.eventListeners.keydown = util.addEventListener(
        document, 'keydown', function (event) {
            me._onKeyDown(event);
        });

        this.selection = util.getSelection();
    this.anchor = anchor;
    setTimeout(function () {
        me.dom.focusButton.focus();
    }, 0);

    if (ContextMenu.visibleMenu) {
        ContextMenu.visibleMenu.hide();
    }
    ContextMenu.visibleMenu = this;
};


ContextMenu.prototype.hide = function () {
        if (this.dom.menu.parentNode) {
        this.dom.menu.parentNode.removeChild(this.dom.menu);
        if (this.onClose) {
            this.onClose();
        }
    }

            for (var name in this.eventListeners) {
        if (this.eventListeners.hasOwnProperty(name)) {
            var fn = this.eventListeners[name];
            if (fn) {
                util.removeEventListener(document, name, fn);
            }
            delete this.eventListeners[name];
        }
    }

    if (ContextMenu.visibleMenu == this) {
        ContextMenu.visibleMenu = undefined;
    }
};


ContextMenu.prototype._onExpandItem = function (domItem) {
    var me = this;
    var alreadyVisible = (domItem == this.expandedItem);

        var expandedItem = this.expandedItem;
    if (expandedItem) {
                expandedItem.ul.style.height = '0';
        expandedItem.ul.style.padding = '';
        setTimeout(function () {
            if (me.expandedItem != expandedItem) {
                expandedItem.ul.style.display = '';
                util.removeClassName(expandedItem.ul.parentNode, 'selected');
            }
        }, 300);         this.expandedItem = undefined;
    }

    if (!alreadyVisible) {
        var ul = domItem.ul;
        ul.style.display = 'block';
        var height = ul.clientHeight;         setTimeout(function () {
            if (me.expandedItem == domItem) {
                ul.style.height = (ul.childNodes.length * 24) + 'px';
                ul.style.padding = '5px 10px';
            }
        }, 0);
        util.addClassName(ul.parentNode, 'selected');
        this.expandedItem = domItem;
    }
};


ContextMenu.prototype._onKeyDown = function (event) {
    event = event || window.event;
    var target = event.target || event.srcElement;
    var keynum = event.which || event.keyCode;
    var handled = false;
    var buttons, targetIndex, prevButton, nextButton;

    if (keynum == 27) {         
                if (this.selection) {
            util.setSelection(this.selection);
        }
        if (this.anchor) {
            this.anchor.focus();
        }

        this.hide();

        handled = true;
    }
    else if (keynum == 9) {         if (!event.shiftKey) {             buttons = this._getVisibleButtons();
            targetIndex = buttons.indexOf(target);
            if (targetIndex == buttons.length - 1) {
                                buttons[0].focus();
                handled = true;
            }
        }
        else {             buttons = this._getVisibleButtons();
            targetIndex = buttons.indexOf(target);
            if (targetIndex == 0) {
                                buttons[buttons.length - 1].focus();
                handled = true;
            }
        }
    }
    else if (keynum == 37) {         if (target.className == 'expand') {
            buttons = this._getVisibleButtons();
            targetIndex = buttons.indexOf(target);
            prevButton = buttons[targetIndex - 1];
            if (prevButton) {
                prevButton.focus();
            }
        }
        handled = true;
    }
    else if (keynum == 38) {         buttons = this._getVisibleButtons();
        targetIndex = buttons.indexOf(target);
        prevButton = buttons[targetIndex - 1];
        if (prevButton && prevButton.className == 'expand') {
                        prevButton = buttons[targetIndex - 2];
        }
        if (!prevButton) {
                        prevButton = buttons[buttons.length - 1];
        }
        if (prevButton) {
            prevButton.focus();
        }
        handled = true;
    }
    else if (keynum == 39) {         buttons = this._getVisibleButtons();
        targetIndex = buttons.indexOf(target);
        nextButton = buttons[targetIndex + 1];
        if (nextButton && nextButton.className == 'expand') {
            nextButton.focus();
        }
        handled = true;
    }
    else if (keynum == 40) {         buttons = this._getVisibleButtons();
        targetIndex = buttons.indexOf(target);
        nextButton = buttons[targetIndex + 1];
        if (nextButton && nextButton.className == 'expand') {
                        nextButton = buttons[targetIndex + 2];
        }
        if (!nextButton) {
                        nextButton = buttons[0];
        }
        if (nextButton) {
            nextButton.focus();
            handled = true;
        }
        handled = true;
    }
    
    if (handled) {
        util.stopPropagation(event);
        util.preventDefault(event);
    }
};


ContextMenu.prototype._isChildOf = function (child, parent) {
    var e = child.parentNode;
    while (e) {
        if (e == parent) {
            return true;
        }
        e = e.parentNode;
    }

    return false;
};



function History (editor) {
    this.editor = editor;
    this.clear();

        this.actions = {
        'editField': {
            'undo': function (params) {
                params.node.updateField(params.oldValue);
            },
            'redo': function (params) {
                params.node.updateField(params.newValue);
            }
        },
        'editValue': {
            'undo': function (params) {
                params.node.updateValue(params.oldValue);
            },
            'redo': function (params) {
                params.node.updateValue(params.newValue);
            }
        },
        'appendNode': {
            'undo': function (params) {
                params.parent.removeChild(params.node);
            },
            'redo': function (params) {
                params.parent.appendChild(params.node);
            }
        },
        'insertBeforeNode': {
            'undo': function (params) {
                params.parent.removeChild(params.node);
            },
            'redo': function (params) {
                params.parent.insertBefore(params.node, params.beforeNode);
            }
        },
        'insertAfterNode': {
            'undo': function (params) {
                params.parent.removeChild(params.node);
            },
            'redo': function (params) {
                params.parent.insertAfter(params.node, params.afterNode);
            }
        },
        'removeNode': {
            'undo': function (params) {
                var parent = params.parent;
                var beforeNode = parent.childs[params.index] || parent.append;
                parent.insertBefore(params.node, beforeNode);
            },
            'redo': function (params) {
                params.parent.removeChild(params.node);
            }
        },
        'duplicateNode': {
            'undo': function (params) {
                params.parent.removeChild(params.clone);
            },
            'redo': function (params) {
                params.parent.insertAfter(params.clone, params.node);
            }
        },
        'changeType': {
            'undo': function (params) {
                params.node.changeType(params.oldType);
            },
            'redo': function (params) {
                params.node.changeType(params.newType);
            }
        },
        'moveNode': {
            'undo': function (params) {
                params.startParent.moveTo(params.node, params.startIndex);
            },
            'redo': function (params) {
                params.endParent.moveTo(params.node, params.endIndex);
            }
        },
        'sort': {
            'undo': function (params) {
                var node = params.node;
                node.hideChilds();
                node.sort = params.oldSort;
                node.childs = params.oldChilds;
                node.showChilds();
            },
            'redo': function (params) {
                var node = params.node;
                node.hideChilds();
                node.sort = params.newSort;
                node.childs = params.newChilds;
                node.showChilds();
            }
        }

                    };
}


History.prototype.onChange = function () {};


History.prototype.add = function (action, params) {
    this.index++;
    this.history[this.index] = {
        'action': action,
        'params': params,
        'timestamp': new Date()
    };

        if (this.index < this.history.length - 1) {
        this.history.splice(this.index + 1, this.history.length - this.index - 1);
    }

        this.onChange();
};


History.prototype.clear = function () {
    this.history = [];
    this.index = -1;

        this.onChange();
};


History.prototype.canUndo = function () {
    return (this.index >= 0);
};


History.prototype.canRedo = function () {
    return (this.index < this.history.length - 1);
};


History.prototype.undo = function () {
    if (this.canUndo()) {
        var obj = this.history[this.index];
        if (obj) {
            var action = this.actions[obj.action];
            if (action && action.undo) {
                action.undo(obj.params);
                if (obj.params.oldSelection) {
                    this.editor.setSelection(obj.params.oldSelection);
                }
            }
            else {
                util.log('Error: unknown action "' + obj.action + '"');
            }
        }
        this.index--;

                this.onChange();
    }
};


History.prototype.redo = function () {
    if (this.canRedo()) {
        this.index++;

        var obj = this.history[this.index];
        if (obj) {
            var action = this.actions[obj.action];
            if (action && action.redo) {
                action.redo(obj.params);
                if (obj.params.newSelection) {
                    this.editor.setSelection(obj.params.newSelection);
                }
            }
            else {
                util.log('Error: unknown action "' + obj.action + '"');
            }
        }

                this.onChange();
    }
};


function SearchBox (editor, container) {
    var searchBox = this;

    this.editor = editor;
    this.timeout = undefined;
    this.delay = 200;     this.lastText = undefined;

    this.dom = {};
    this.dom.container = container;

    var table = document.createElement('table');
    this.dom.table = table;
    table.className = 'search';
    container.appendChild(table);
    var tbody = document.createElement('tbody');
    this.dom.tbody = tbody;
    table.appendChild(tbody);
    var tr = document.createElement('tr');
    tbody.appendChild(tr);

    var td = document.createElement('td');
    tr.appendChild(td);
    var results = document.createElement('div');
    this.dom.results = results;
    results.className = 'results';
    td.appendChild(results);

    td = document.createElement('td');
    tr.appendChild(td);
    var divInput = document.createElement('div');
    this.dom.input = divInput;
    divInput.className = 'frame';
    divInput.title = 'Search fields and values';
    td.appendChild(divInput);

        var tableInput = document.createElement('table');
    divInput.appendChild(tableInput);
    var tbodySearch = document.createElement('tbody');
    tableInput.appendChild(tbodySearch);
    tr = document.createElement('tr');
    tbodySearch.appendChild(tr);

    var refreshSearch = document.createElement('button');
    refreshSearch.className = 'refresh';
    td = document.createElement('td');
    td.appendChild(refreshSearch);
    tr.appendChild(td);

    var search = document.createElement('input');
    this.dom.search = search;
    search.oninput = function (event) {
        searchBox._onDelayedSearch(event);
    };
    search.onchange = function (event) {         searchBox._onSearch(event);
    };
    search.onkeydown = function (event) {
        searchBox._onKeyDown(event);
    };
    search.onkeyup = function (event) {
        searchBox._onKeyUp(event);
    };
    refreshSearch.onclick = function (event) {
        search.select();
    };

        td = document.createElement('td');
    td.appendChild(search);
    tr.appendChild(td);

    var searchNext = document.createElement('button');
    searchNext.title = 'Next result (Enter)';
    searchNext.className = 'next';
    searchNext.onclick = function () {
        searchBox.next();
    };
    td = document.createElement('td');
    td.appendChild(searchNext);
    tr.appendChild(td);

    var searchPrevious = document.createElement('button');
    searchPrevious.title = 'Previous result (Shift+Enter)';
    searchPrevious.className = 'previous';
    searchPrevious.onclick = function () {
        searchBox.previous();
    };
    td = document.createElement('td');
    td.appendChild(searchPrevious);
    tr.appendChild(td);
}


SearchBox.prototype.next = function(focus) {
    if (this.results != undefined) {
        var index = (this.resultIndex != undefined) ? this.resultIndex + 1 : 0;
        if (index > this.results.length - 1) {
            index = 0;
        }
        this._setActiveResult(index, focus);
    }
};


SearchBox.prototype.previous = function(focus) {
    if (this.results != undefined) {
        var max = this.results.length - 1;
        var index = (this.resultIndex != undefined) ? this.resultIndex - 1 : max;
        if (index < 0) {
            index = max;
        }
        this._setActiveResult(index, focus);
    }
};


SearchBox.prototype._setActiveResult = function(index, focus) {
        if (this.activeResult) {
        var prevNode = this.activeResult.node;
        var prevElem = this.activeResult.elem;
        if (prevElem == 'field') {
            delete prevNode.searchFieldActive;
        }
        else {
            delete prevNode.searchValueActive;
        }
        prevNode.updateDom();
    }

    if (!this.results || !this.results[index]) {
                this.resultIndex = undefined;
        this.activeResult = undefined;
        return;
    }

    this.resultIndex = index;

        var node = this.results[this.resultIndex].node;
    var elem = this.results[this.resultIndex].elem;
    if (elem == 'field') {
        node.searchFieldActive = true;
    }
    else {
        node.searchValueActive = true;
    }
    this.activeResult = this.results[this.resultIndex];
    node.updateDom();

        node.scrollTo(function () {
        if (focus) {
            node.focus(elem);
        }
    });
};


SearchBox.prototype._clearDelay = function() {
    if (this.timeout != undefined) {
        clearTimeout(this.timeout);
        delete this.timeout;
    }
};


SearchBox.prototype._onDelayedSearch = function (event) {
            this._clearDelay();
    var searchBox = this;
    this.timeout = setTimeout(function (event) {
            searchBox._onSearch(event);
        },
        this.delay);
};


SearchBox.prototype._onSearch = function (event, forceSearch) {
    this._clearDelay();

    var value = this.dom.search.value;
    var text = (value.length > 0) ? value : undefined;
    if (text != this.lastText || forceSearch) {
                this.lastText = text;
        this.results = this.editor.search(text);
        this._setActiveResult(undefined);

                if (text != undefined) {
            var resultCount = this.results.length;
            switch (resultCount) {
                case 0: this.dom.results.innerHTML = 'no&nbsp;results'; break;
                case 1: this.dom.results.innerHTML = '1&nbsp;result'; break;
                default: this.dom.results.innerHTML = resultCount + '&nbsp;results'; break;
            }
        }
        else {
            this.dom.results.innerHTML = '';
        }
    }
};


SearchBox.prototype._onKeyDown = function (event) {
    event = event || window.event;
    var keynum = event.which || event.keyCode;
    if (keynum == 27) {         this.dom.search.value = '';          this._onSearch(event);
        util.preventDefault(event);
        util.stopPropagation(event);
    }
    else if (keynum == 13) {         if (event.ctrlKey) {
                        this._onSearch(event, true);
        }
        else if (event.shiftKey) {
                        this.previous();
        }
        else {
                        this.next();
        }
        util.preventDefault(event);
        util.stopPropagation(event);
    }
};


SearchBox.prototype._onKeyUp = function (event) {
    event = event || window.event;
    var keynum = event.which || event.keyCode;
    if (keynum != 27 && keynum != 13) {         this._onDelayedSearch(event);       }
};


function Highlighter () {
    this.locked = false;
}


Highlighter.prototype.highlight = function (node) {
    if (this.locked) {
        return;
    }

    if (this.node != node) {
                if (this.node) {
            this.node.setHighlight(false);
        }

                this.node = node;
        this.node.setHighlight(true);
    }

        this._cancelUnhighlight();
};


Highlighter.prototype.unhighlight = function () {
    if (this.locked) {
        return;
    }

    var me = this;
    if (this.node) {
        this._cancelUnhighlight();

                                this.unhighlightTimer = setTimeout(function () {
            me.node.setHighlight(false);
            me.node = undefined;
            me.unhighlightTimer = undefined;
        }, 0);
    }
};


Highlighter.prototype._cancelUnhighlight = function () {
    if (this.unhighlightTimer) {
        clearTimeout(this.unhighlightTimer);
        this.unhighlightTimer = undefined;
    }
};


Highlighter.prototype.lock = function () {
    this.locked = true;
};


Highlighter.prototype.unlock = function () {
    this.locked = false;
};

util = {};

if(!Array.prototype.indexOf) {
    Array.prototype.indexOf = function(obj){
        for(var i = 0; i < this.length; i++){
            if(this[i] == obj){
                return i;
            }
        }
        return -1;
    }
}

if (!Array.prototype.forEach) {
    Array.prototype.forEach = function(fn, scope) {
        for(var i = 0, len = this.length; i < len; ++i) {
            fn.call(scope || this, this[i], i, this);
        }
    }
}


util.parse = function (jsonString) {
    try {
        return JSON.parse(jsonString);
    }
    catch (err) {
                util.validate(jsonString);
        throw err;
    }
};


util.validate = function (jsonString) {
    if (typeof(jsonlint) != 'undefined') {
        jsonlint.parse(jsonString);
    }
    else {
        JSON.parse(jsonString);
    }
};


util.extend = function (a, b) {
    for (var prop in b) {
        if (b.hasOwnProperty(prop)) {
            a[prop] = b[prop];
        }
    }
    return a;
};


util.clear = function (a) {
    for (var prop in a) {
        if (a.hasOwnProperty(prop)) {
            delete a[prop];
        }
    }
    return a;
};


util.log = function(args) {
    if (console && typeof console.log === 'function') {
        console.log.apply(console, arguments);
    }
};


var isUrlRegex = /^https?:\/\/\S+$/;
util.isUrl = function (text) {
    return (typeof text == 'string' || text instanceof String) &&
        isUrlRegex.test(text);
};


util.getAbsoluteLeft = function (elem) {
    var left = elem.offsetLeft;
    var body = document.body;
    var e = elem.offsetParent;
    while (e != null && elem != body) {
        left += e.offsetLeft;
        left -= e.scrollLeft;
        e = e.offsetParent;
    }
    return left;
};


util.getAbsoluteTop = function (elem) {
    var top = elem.offsetTop;
    var body = document.body;
    var e = elem.offsetParent;
    while (e != null && e != body) {
        top += e.offsetTop;
        top -= e.scrollTop;
        e = e.offsetParent;
    }
    return top;
};


util.getMouseY = function (event) {
    var mouseY;
    if ('pageY' in event) {
        mouseY = event.pageY;
    }
    else {
                mouseY = (event.clientY + document.documentElement.scrollTop);
    }

    return mouseY;
};


util.getMouseX = function (event) {
    var mouseX;
    if ('pageX' in event) {
        mouseX = event.pageX;
    }
    else {
                mouseX = (event.clientX + document.documentElement.scrollLeft);
    }

    return mouseX;
};


util.getWindowHeight = function () {
    if ('innerHeight' in window) {
        return window.innerHeight;
    }
    else {
                return Math.max(document.body.clientHeight,
            document.documentElement.clientHeight);
    }
};


util.addClassName = function(elem, className) {
    var classes = elem.className.split(' ');
    if (classes.indexOf(className) == -1) {
        classes.push(className);         elem.className = classes.join(' ');
    }
};


util.removeClassName = function(elem, className) {
    var classes = elem.className.split(' ');
    var index = classes.indexOf(className);
    if (index != -1) {
        classes.splice(index, 1);         elem.className = classes.join(' ');
    }
};


util.stripFormatting = function (divElement) {
    var childs = divElement.childNodes;
    for (var i = 0, iMax = childs.length; i < iMax; i++) {
        var child = childs[i];

                if (child.style) {
                        child.removeAttribute('style');
        }

                var attributes = child.attributes;
        if (attributes) {
            for (var j = attributes.length - 1; j >= 0; j--) {
                var attribute = attributes[j];
                if (attribute.specified == true) {
                    child.removeAttribute(attribute.name);
                }
            }
        }

                util.stripFormatting(child);
    }
};


util.setEndOfContentEditable = function (contentEditableElement) {
    var range, selection;
    if(document.createRange) {        range = document.createRange();        range.selectNodeContents(contentEditableElement);        range.collapse(false);        selection = window.getSelection();        selection.removeAllRanges();        selection.addRange(range);    }
    else if(document.selection) {        range = document.body.createTextRange();        range.moveToElementText(contentEditableElement);        range.collapse(false);        range.select();    }
};


util.selectContentEditable = function (contentEditableElement) {
    if (!contentEditableElement || contentEditableElement.nodeName != 'DIV') {
        return;
    }

    var sel, range;
    if (window.getSelection && document.createRange) {
        range = document.createRange();
        range.selectNodeContents(contentEditableElement);
        sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
    } else if (document.body.createTextRange) {
        range = document.body.createTextRange();
        range.moveToElementText(contentEditableElement);
        range.select();
    }
};


util.getSelection = function () {
    if (window.getSelection) {
        var sel = window.getSelection();
        if (sel.getRangeAt && sel.rangeCount) {
            return sel.getRangeAt(0);
        }
    } else if (document.selection && document.selection.createRange) {
        return document.selection.createRange();
    }
    return null;
};


util.setSelection = function (range) {
    if (range) {
        if (window.getSelection) {
            var sel = window.getSelection();
            sel.removeAllRanges();
            sel.addRange(range);
        } else if (document.selection && range.select) {
            range.select();
        }
    }
};


util.getSelectionOffset = function () {
    var range = util.getSelection();

    if (range && 'startOffset' in range && 'endOffset' in range &&
            range.startContainer && (range.startContainer == range.endContainer)) {
        return {
            startOffset: range.startOffset,
            endOffset: range.endOffset,
            container: range.startContainer.parentNode
        };
    }
    else {
            }

    return null;
};


util.setSelectionOffset = function (params) {
    if (document.createRange && window.getSelection) {
        var selection = window.getSelection();
        if(selection) {
            var range = document.createRange();
                                    range.setStart(params.container.firstChild, params.startOffset);
            range.setEnd(params.container.firstChild, params.endOffset);

            util.setSelection(range);
        }
    }
    else {
            }
};


util.getInnerText = function (element, buffer) {
    var first = (buffer == undefined);
    if (first) {
        buffer = {
            'text': '',
            'flush': function () {
                var text = this.text;
                this.text = '';
                return text;
            },
            'set': function (text) {
                this.text = text;
            }
        };
    }

        if (element.nodeValue) {
        return buffer.flush() + element.nodeValue;
    }

        if (element.hasChildNodes()) {
        var childNodes = element.childNodes;
        var innerText = '';

        for (var i = 0, iMax = childNodes.length; i < iMax; i++) {
            var child = childNodes[i];

            if (child.nodeName == 'DIV' || child.nodeName == 'P') {
                var prevChild = childNodes[i - 1];
                var prevName = prevChild ? prevChild.nodeName : undefined;
                if (prevName && prevName != 'DIV' && prevName != 'P' && prevName != 'BR') {
                    innerText += '\n';
                    buffer.flush();
                }
                innerText += util.getInnerText(child, buffer);
                buffer.set('\n');
            }
            else if (child.nodeName == 'BR') {
                innerText += buffer.flush();
                buffer.set('\n');
            }
            else {
                innerText += util.getInnerText(child, buffer);
            }
        }

        return innerText;
    }
    else {
        if (element.nodeName == 'P' && util.getInternetExplorerVersion() != -1) {
                                                                        return buffer.flush();
        }
    }

        return '';
};


util.getInternetExplorerVersion = function() {
    if (_ieVersion == -1) {
        var rv = -1;         if (navigator.appName == 'Microsoft Internet Explorer')
        {
            var ua = navigator.userAgent;
            var re  = new RegExp("MSIE ([0-9]{1,}[\.0-9]{0,})");
            if (re.exec(ua) != null) {
                rv = parseFloat( RegExp.$1 );
            }
        }

        _ieVersion = rv;
    }

    return _ieVersion;
};


var _ieVersion = -1;


util.addEventListener = function (element, action, listener, useCapture) {
    if (element.addEventListener) {
        if (useCapture === undefined)
            useCapture = false;

        if (action === "mousewheel" && navigator.userAgent.indexOf("Firefox") >= 0) {
            action = "DOMMouseScroll";          }

        element.addEventListener(action, listener, useCapture);
        return listener;
    } else {
                var f = function () {
            return listener.call(element, window.event);
        };
        element.attachEvent("on" + action, f);
        return f;
    }
};


util.removeEventListener = function(element, action, listener, useCapture) {
    if (element.removeEventListener) {
                if (useCapture === undefined)
            useCapture = false;

        if (action === "mousewheel" && navigator.userAgent.indexOf("Firefox") >= 0) {
            action = "DOMMouseScroll";          }

        element.removeEventListener(action, listener, useCapture);
    } else {
                element.detachEvent("on" + action, listener);
    }
};



util.stopPropagation = function (event) {
    if (!event) {
        event = window.event;
    }

    if (event.stopPropagation) {
        event.stopPropagation();      }
    else {
        event.cancelBubble = true;      }
};



util.preventDefault = function (event) {
    if (!event) {
        event = window.event;
    }

    if (event.preventDefault) {
        event.preventDefault();      }
    else {
        event.returnValue = false;      }
};


var jsoneditor = {
    'JSONEditor': JSONEditor,
    'JSONFormatter': function () {
        throw new Error('JSONFormatter is deprecated. ' +
            'Use JSONEditor with mode "text" or "code" instead');
    },
    'util': util
};


var loadCss = function () {
            var scripts = document.getElementsByTagName('script');
    var jsFile = scripts[scripts.length-1].src.split('?')[0];
    var cssFile = jsFile.substring(0, jsFile.length - 2) + 'css';

        var link = document.createElement('link');
    link.type = 'text/css';
    link.rel = 'stylesheet';
    link.href = cssFile;
    document.getElementsByTagName('head')[0].appendChild(link);
};


if (typeof(module) != 'undefined' && typeof(exports) != 'undefined') {
    loadCss();
    module.exports = exports = jsoneditor;
}


if (typeof(require) != 'undefined' && typeof(define) != 'undefined') {
    define(function () {
        loadCss();
        return jsoneditor;
    });
}
else {
        window['jsoneditor'] = jsoneditor;
}


})();
