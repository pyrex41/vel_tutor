/*
 * TopBar - v2.0.2 - 2014-06-16
 * http://buunguyen.github.io/topbar
 * Copyright (c) 2014 Bui Nguyet Anh; Licensed MIT */

const topbarModule = (function (window, document) {
  "use strict";

  // https://gist.github.com/paulirish/1579671
  (function (vendor, feature) {
    if (typeof document !== 'object' || typeof document.createElement !== 'function') {
      return;
    }
    var d = document.createElement('div');
    var prefixes = 'O Moz Webkit Ms'.split(' ');
    var len = prefixes.length;

    if (typeof d.style[feature] === 'string') {
      return;
    }

    feature = feature.charAt(0).toUpperCase() + feature.substr(1);
    for (var i = 0; i < len; i++) {
      if (typeof d.style[prefixes[i] + feature] === 'string') {
        return;
      }
    }
  })('transition', 'transition');

  var transitionPrefix = (function () {
    var d = document.createElement('div');
    var prefixes = ['Webkit', 'Moz', 'Ms', 'O'];
    var len = prefixes.length;

    for (var i = 0; i < len; i++) {
      if (typeof d.style[prefixes[i] + 'Transition'] === 'string') {
        return '-' + prefixes[i].toLowerCase() + '-';
      }
    }
    return '';
  })();

  var topbar = {

    config: {
      autoRun: true,
      barThickness: 3,
      barColors: {
        '0': 'rgba(26,  188, 156, .9)',
        '.25': 'rgba(52,  152, 219, .9)',
        '.50': 'rgba(241, 196, 15,  .9)',
        '.75': 'rgba(230, 126, 34,  .9)',
        '1.0': 'rgba(211, 84,  0,   .9)'
      },
      shadowBlur: 10,
      shadowColor: 'rgba(0,   0,   0,   .6)',
      className: 'topbar'
    },

    configure: function (options) {
      for (var key in options) {
        if (options.hasOwnProperty(key)) {
          this.config[key] = options[key];
        }
      }
    },

    show: function (options) {
      if (options) {
        this.configure(options);
      }

      if (!this.element) {
        this.element = document.createElement('div');
        this.element.className = this.config.className + ' topbar-element';
        this.element.style.position = 'fixed';
        this.element.style.top = '0';
        this.element.style.left = '0';
        this.element.style.right = '0';
        this.element.style.height = this.config.barThickness + 'px';
        this.element.style.backgroundColor = this.config.barColors['0'];
        this.element.style['-webkit-transition'] = 'all 0 linear';
        this.element.style['-moz-transition'] = 'all 0 linear';
        this.element.style['-ms-transition'] = 'all 0 linear';
        this.element.style['-o-transition'] = 'all 0 linear';
        this.element.style.transition = 'all 0 linear';
        this.element.style['-webkit-transform'] = 'translateY(' + (-this.config.barThickness * 2) + 'px)';
        this.element.style['-moz-transform'] = 'translateY(' + (-this.config.barThickness * 2) + 'px)';
        this.element.style['-ms-transform'] = 'translateY(' + (-this.config.barThickness * 2) + 'px)';
        this.element.style['-o-transform'] = 'translateY(' + (-this.config.barThickness * 2) + 'px)';
        this.element.style.transform = 'translateY(' + (-this.config.barThickness * 2) + 'px)';
        this.element.style['-webkit-box-shadow'] = '0 ' + this.config.barThickness + 'px ' + this.config.shadowBlur + 'px ' + this.config.shadowColor;
        this.element.style['-moz-box-shadow'] = '0 ' + this.config.barThickness + 'px ' + this.config.shadowBlur + 'px ' + this.config.shadowColor;
        this.element.style['box-shadow'] = '0 ' + this.config.barThickness + 'px ' + this.config.shadowBlur + 'px ' + this.config.shadowColor;

        if (document.body) {
          document.body.appendChild(this.element);
        } else {
          throw new Error('topbar requires a body element in the page');
        }
      }

      if (this.element) {
        this.percent = 0;
        this.element.style['-webkit-transform'] = 'translateY(0)';
        this.element.style['-moz-transform'] = 'translateY(0)';
        this.element.style['-ms-transform'] = 'translateY(0)';
        this.element.style['-o-transform'] = 'translateY(0)';
        this.element.style.transform = 'translateY(0)';
      }

      this.interval = setInterval(this.update, 16);
    },

    hide: function () {
      if (this.element) {
        this.element.style['-webkit-transform'] = 'translateY(' + (-this.config.barThickness * 2) + 'px)';
        this.element.style['-moz-transform'] = 'translateY(' + (-this.config.barThickness * 2) + 'px)';
        this.element.style['-ms-transform'] = 'translateY(' + (-this.config.barThickness * 2) + 'px)';
        this.element.style['-o-transform'] = 'translateY(' + (-this.config.barThickness * 2) + 'px)';
        this.element.style.transform = 'translateY(' + (-this.config.barThickness * 2) + 'px)';
        this.element.style['-webkit-transition'] = 'all .3s ease-in-out';
        this.element.style['-moz-transition'] = 'all .3s ease-in-out';
        this.element.style['-ms-transition'] = 'all .3s ease-in-out';
        this.element.style['-o-transition'] = 'all .3s ease-in-out';
        this.element.style.transition = 'all .3s ease-in-out';
        setTimeout(function () {
          if (topbar.element && topbar.element.parentNode) {
            topbar.element.parentNode.removeChild(topbar.element);
          }
          topbar.element = null;
        }, 300);
      }
      clearInterval(this.interval);
    },

    update: function () {
      if (topbar.element) {
        topbar.percent += Math.random() * 1.5;
        if (topbar.percent >= 100) {
          topbar.percent = 99.9;
        }
        topbar.element.style.width = topbar.percent + '%';
        var color = topbar.config.barColors[Math.floor(topbar.percent / 25)];
        if (color) {
          topbar.element.style.backgroundColor = color;
        }
      }
    }
  };

  // Return topbar for module systems
  return topbar;

}).call(this, window, document);

// ES module export
export default topbarModule;