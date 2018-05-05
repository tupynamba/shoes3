#include "shoes/types/native.h"
#include "shoes/app.h"
#include "shoes/types/settings.h"
/*
 * The settings object
 */ 
// ruby
VALUE cSettings;

#if 0
void shoes_settings_init() {
    cSettings  = rb_define_class_under(cShoes, "Settings", rb_cObject);
    rb_define_alloc_func(cSettings, shoes_settings_alloc);
    rb_define_method(cSettings, "dbus", CASTHOOK(shoes_settings_dbus),0);
    //rb_define_method(cShoesMenubar, "[]", CASTHOOK(shoes_menubar_at), 1);
    //RUBY_M("+settings", settings, -1);
}
#endif

void shoes_settings_mark(shoes_settings *st) {
    rb_gc_mark_maybe(st->app_name);
    rb_gc_mark_maybe(st->theme);
    rb_gc_mark_maybe(st->mdi);
    rb_gc_mark_maybe(st->rdomain);
    rb_gc_mark_maybe(st->mdi);
    rb_gc_mark_maybe(st->use_menus);
    rb_gc_mark_maybe(st->dbus_name);
}

static void shoes_settings_free(shoes_settings *st) {
    RUBY_CRITICAL(SHOE_FREE(st));
}

VALUE shoes_settings_alloc(VALUE klass) {
    VALUE obj;
    shoes_settings *st = SHOE_ALLOC(shoes_settings);
    SHOE_MEMZERO(st, shoes_settings, 1);
    obj = Data_Wrap_Struct(klass, shoes_settings_mark, shoes_settings_free, st);
    st->app_name = Qnil;
    st->theme = Qnil;
    st->mdi = Qnil;
    st->rdomain = Qnil;
    st->use_menus = Qnil;
    st->dbus_name = Qnil;
    return obj;
}

/*
 * This should only be called once, early in Shoes startup
 * Save in a global ruby object - not a Shoes GUI object. 
 * There is a one time, small bit of memory that is not free-ed. 
*/

VALUE shoes_settings_new(shoes_yaml_init *yml) {
  shoes_settings *st;
  Data_Get_Struct(shoes_world->settings, shoes_settings, st);
  st->app_name = rb_str_new2(yml->app_name);
  
  if (yml->theme_name == NULL)
    st->theme = Qnil;
  else
    st->theme = rb_str_new2(yml->theme_name);
    
  st->rdomain = rb_str_new2(yml->rdomain);
  
  if (! strcmp(yml->mdi,"true")) 
    st->mdi = Qtrue;
  else
    st->mdi = Qnil;
    
  if (! strcmp(yml->use_menus, "true"))
    st->use_menus = Qtrue;
  else
    st->use_menus = Qnil;
    
  // TODO: shoes_native_monitor_check
  //free(yml);
  return shoes_world->settings; 
}

/*
 * Returns the dbus registered name
 * Only useful on Linux
*/
VALUE shoes_settings_dbus(VALUE self) {
  shoes_settings *st;
  Data_Get_Struct(self, shoes_settings, st);
  return st->dbus_name;
}

/* 
 * Returns the app_name ("Shoes" default). Can be set via
 * shoes.yaml or (app.set_window_title ?)
*/
VALUE shoes_settings_app_name(VALUE self) {
  shoes_settings *st;
  Data_Get_Struct(self, shoes_settings, st);
  return st->app_name;  
}

/* 
 * Theme name. Path is somewhere in Shoes share/ ??
 * Not useable in OSX/cocoa.
*/
VALUE shoes_settings_get_theme(VALUE self) {
  shoes_settings *st;
  Data_Get_Struct(self, shoes_settings, st);
  return st->theme;
}

VALUE shoes_settings_set_theme(VALUE self, VALUE theme) {
  shoes_settings *st;
  Data_Get_Struct(self, shoes_settings, st);
  st->theme = theme;
  // TODO: Trigger gtk to do something?
  return st->theme;
}

// get mdi status - not useful, IMO
// TODO: use integer not VALUE
VALUE shoes_settings_mdi(VALUE self) {
  shoes_settings *st;
  Data_Get_Struct(self, shoes_settings, st);
  return st->mdi == Qtrue ? Qtrue: Qfalse;
}

// Return menu status (it's global once set for any Shoes.app window
// TODO: use integer instead of VALUE
VALUE shoes_settings_menu(VALUE self) {
  shoes_settings *st;
  Data_Get_Struct(self, shoes_settings, st);
  return st->use_menus == Qtrue ? Qtrue : Qfalse;
}

VALUE shoes_settings_rdomain(VALUE self) {
  shoes_settings *st;
  Data_Get_Struct(self, shoes_settings, st);
  return st->rdomain;
}

VALUE shoes_settings_set_rdomain(VALUE self, VALUE name) {
  shoes_settings *st;
  Data_Get_Struct(self, shoes_settings, st);
  st->rdomain = name;
  return st->rdomain;
}

// There is always one monitor
VALUE shoes_settings_monitor_count(VALUE self) {
  shoes_settings *st;
  Data_Get_Struct(self, shoes_settings, st);
  int cnt = shoes_native_monitor_count(); 
  return INT2NUM(cnt);
}


VALUE shoes_settings_monitor_geometry(VALUE self, VALUE idx) {
  shoes_settings *st;
  Data_Get_Struct(self, shoes_settings, st);
  shoes_monitor_t rect;
  shoes_native_monitor_geometry(NUM2INT(idx), &rect);
  VALUE ary = rb_ary_new3(4, INT2NUM(rect.x), INT2NUM(rect.y), 
      INT2NUM(rect.width), INT2NUM(rect.height));
  return ary;
}

VALUE shoes_settings_monitor_default(VALUE self) {
  shoes_settings *st;
  Data_Get_Struct(self, shoes_settings, st);
  int mon;
  mon = shoes_native_monitor_default();
  return INT2NUM(mon);  
}