# encoding: UTF-8

# 
# Credits, inspiration goes to : 
# https://github.com/emilsoman/diy_prof/tree/dot-reporter
# 

module TimeHelpers
    # These methods make use of `clock_gettime` method introduced in Ruby 2.1
    # to measure CPU time and Wall clock time. (microsecond is second / 1 000 000)
    def cpu_time
        Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID, :microsecond)
    end

    def wall_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
    end
end

class Tracer
    include TimeHelpers
    EVENTS = [:call, :return, :c_call, :c_return]
    
    def initialize(reporter, c_calls)
        @reporter = reporter
        events = c_calls ? EVENTS : EVENTS - [:c_call, :c_return]
        
        @tracepoints = events.map do |event|
            TracePoint.new(event) do |trace|
                reporter.record(event, trace.method_id, cpu_time)
            end
        end
        
    end
    
    def enable; @tracepoints.each(&:enable) end
    def disable; @tracepoints.each(&:disable) end
    def result; @reporter.result end
end


CallInfo = Struct.new(:name, :time)
MethodInfo = Struct.new(:count, :total_time, :self_time)

class Reporter
    def initialize
        # A stack for pushing/popping methods when methods get called/returned
        @call_stack = []
        # Nodes for all methods
        @methods = {}
        # Connections between the nodes
        @calls = {}
    end

    def record(event, method_name, time)
        case event
        when :call, :c_call
            @call_stack << CallInfo.new(method_name, time)
        when :return, :c_return
            # Return cannot be the first event in the call stack
            return if @call_stack.empty?

            method = @call_stack.pop
            # Set execution time of method in call info
            method.time = time - method.time
            
            add_method_to_call_tree(method)
        end
    end
    
    def result
        [@methods, @calls]
    end

    private
    
    def add_method_to_call_tree(method)
        # Add method as a node to the call graph
        @methods[method.name] ||= MethodInfo.new(0, 0, 0)
        # Update total time(spent inside the method and methods called inside this method)
        @methods[method.name].total_time += method.time
        # Update self time(spent inside the method and not methods called inside this method)
        # This will be subtracted when children are added to the graph
        @methods[method.name].self_time += method.time
        # Update total no of times the method was called
        @methods[method.name].count += 1

        # If the method has a parent in the call stack
        # Add a connection from the parent node to this method
        if parent = @call_stack.last
            @calls[parent.name] ||= {}
            @calls[parent.name][method.name] ||= 0
            @calls[parent.name][method.name] += 1

            # Take away self time of parent
            @methods[parent.name] ||= MethodInfo.new(0, 0, 0)
            @methods[parent.name].self_time -= method.time
        end
    end

end


class RadioLabel < Shoes::Widget
    
    def initialize(options={})
        label = options[:text] || ""
        active = options[:active] || false
        inner_margins = options[:inner_margins] || [0,0,0,0]
        r_margins = inner_margins.dup; r_margins[2] = 5 
        p_margins = [0,3] + inner_margins[2..3]
        
        @r = radio checked: active, margin: r_margins
        @p = para label, margin: p_margins
    end
    
    def checked?; @r.checked? end
    def checked=(bool); @r.checked = bool end
end

class NodeWidget < Shoes::Widget
    def initialize(options={})
        name, method_info = options[:node]
        size = options[:size]*8
        ca = options[:color_alpha]
        infos = options[:info]
        self.width = size+4; self.height = size/2+4
        
        stack width: size+4, height: size/2+4 do
            oval 2,2, size, size/2, fill: ca == 1.0 ? red : red(ca)
            @n = inscription "#{name}\n#{infos}", font: "mono", align: "center", margin: 0, displace_top: (size/4)-8
        end
    end
end



class DiyProf < Shoes
    # TODO find how to construct a graph with connected nodes (like Graphviz) ...
    
    url "/", :index
    
    def index
        stack do
            button "choose file", margin: 10 do
                @file = ask_open_file
                if @file
                    @file_para.text = @file
                    @trace_button.state = nil
                else
                    @file_para.text = "no rubies, no trace !"
                    @trace_button.state = "disabled"
                end
            end
            
            flow margin: 20 do
                stack width: 200 do
                    @r1 = radio_label text:"count", active: true 
                    @r2 = radio_label text:"self time"
                    @r3 = radio_label text:"total time"
                    flow(margin_top: 5) { @cc = check checked: false; para "include C methods call" }
                end
                @trace_button = button 'trace', state: "disabled" do
                    Dir.chdir(File.dirname(@file)) do
                      nodes, links = trace { eval IO.read(@file).force_encoding("UTF-8"), TOPLEVEL_BINDING }
                      # need a clever way to hook to the window close of the target - then compute and display results
                      build_nodes(nodes, links)
                    end
                end
                @file_para = para ""
            end
            
            @units = para "", margin_left: 20
            @result_slot = flow(margin: 5) {}
            
        end
    end
    
    def trace
        @tracer = nil if @tracer
        @tracer = Tracer.new(Reporter.new, @cc.checked?)
        
        @tracer.enable
        yield
        @tracer.disable
        @tracer.result
    end
    
    def build_nodes(nodes, links)
        max = nodes.sort_by { |n,mi| n.length }[-1][0].length
        
        filter = 
        if @r1.checked?
            @units.text = "number of times method is called"
            :count
        elsif @r2.checked?
            @units.text = "total time spent by the method alone in microseconds"
            :self_time
        else
            @units.text = "total time spent by the method and subsequent other methods calls in microseconds"
            :total_time
        end
        
        sorted = nodes.sort_by { |n,mi| mi.send(filter) }
        usage = sorted.map {|arr| arr[1].send(filter) }
        unik = usage.uniq
        
        pre_nodes = sorted.reverse.reduce({}) do |memo,(name, method_info)|
            ca = 1.0/unik.size*(unik.index(method_info.send(filter))+1)
            memo.merge "#{name}": { node: [name, method_info], size: max, 
                                    color_alpha: ca, info: method_info.send(filter).to_s }
        end
        
        @result_slot.clear { pre_nodes.each { |k,v| node_widget v } }
        
    end
end
Shoes.app width: 900, height: 700, title: "Tracer"
