import React, { useState } from 'react';
import { Mail, Linkedin, MapPin, Send, CheckCircle, ArrowUpRight } from 'lucide-react';
import { personalInfo } from '../data/mock';

const Contact = () => {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    subject: '',
    message: ''
  });
  const [isSubmitted, setIsSubmitted] = useState(false);

  const handleSubmit = (e) => {
    e.preventDefault();
    // Mock submission - data saved to localStorage for demo
    const submissions = JSON.parse(localStorage.getItem('contactSubmissions') || '[]');
    submissions.push({ ...formData, timestamp: new Date().toISOString() });
    localStorage.setItem('contactSubmissions', JSON.stringify(submissions));
    setIsSubmitted(true);
    setTimeout(() => {
      setIsSubmitted(false);
      setFormData({ name: '', email: '', subject: '', message: '' });
    }, 3000);
  };

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const openForOptions = [
    'Full-time opportunities (Senior DevOps Engineer, Platform Engineer, SRE, Cloud Architect)',
    'Contract/consulting engagements (cloud migrations, compliance implementations, cost optimization)',
    'Technical conversations about cloud architecture, Kubernetes, or DevOps practices',
    'Networking with folks in healthcare technology or multi-cloud environments'
  ];

  return (
    <section id="contact" className="py-24 bg-[#302f2c]/30 relative">
      <div className="absolute top-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-[#3f4816] to-transparent" />
      
      <div className="max-w-7xl mx-auto px-6 lg:px-10">
        {/* Section Header */}
        <div className="mb-16">
          <span className="text-[#d9fb06] text-sm font-semibold uppercase tracking-widest">Get in Touch</span>
          <h2 className="text-4xl md:text-5xl font-black text-[#f5f5f4] mt-4 leading-tight">
            Let's Connect<br />
            <span className="text-[#888680]">& Build Something</span>
          </h2>
        </div>

        <div className="grid lg:grid-cols-2 gap-12">
          {/* Contact Info */}
          <div className="space-y-8">
            <p className="text-lg text-[#888680] leading-relaxed">
              I'm always interested in connecting with people working on interesting infrastructure challenges, 
              particularly in healthcare technology, fintech, or companies taking security and compliance seriously.
            </p>

            {/* Contact Methods */}
            <div className="space-y-4">
              <a
                href={personalInfo.linkedin}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-4 p-5 bg-[#1a1c1b] border border-[#3f4816]/50 rounded-xl hover:border-[#d9fb06]/30 transition-all group"
              >
                <div className="p-3 bg-[#302f2c] rounded-lg">
                  <Linkedin className="text-[#d9fb06]" size={24} />
                </div>
                <div className="flex-1">
                  <p className="text-[#f5f5f4] font-medium group-hover:text-[#d9fb06] transition-colors">LinkedIn</p>
                  <p className="text-[#888680] text-sm">linkedin.com/in/hansennkefor</p>
                </div>
                <ArrowUpRight className="text-[#888680] group-hover:text-[#d9fb06] transition-colors" size={20} />
              </a>

              <a
                href={`mailto:${personalInfo.email}`}
                className="flex items-center gap-4 p-5 bg-[#1a1c1b] border border-[#3f4816]/50 rounded-xl hover:border-[#d9fb06]/30 transition-all group"
              >
                <div className="p-3 bg-[#302f2c] rounded-lg">
                  <Mail className="text-[#d9fb06]" size={24} />
                </div>
                <div className="flex-1">
                  <p className="text-[#f5f5f4] font-medium group-hover:text-[#d9fb06] transition-colors">Email</p>
                  <p className="text-[#888680] text-sm">{personalInfo.email}</p>
                </div>
                <ArrowUpRight className="text-[#888680] group-hover:text-[#d9fb06] transition-colors" size={20} />
              </a>

              <div className="flex items-center gap-4 p-5 bg-[#1a1c1b] border border-[#3f4816]/50 rounded-xl">
                <div className="p-3 bg-[#302f2c] rounded-lg">
                  <MapPin className="text-[#d9fb06]" size={24} />
                </div>
                <div>
                  <p className="text-[#f5f5f4] font-medium">Location</p>
                  <p className="text-[#888680] text-sm">{personalInfo.location} (open to remote)</p>
                </div>
              </div>
            </div>

            {/* Open For */}
            <div className="p-6 bg-[#1a1c1b] border border-[#3f4816]/50 rounded-xl">
              <h4 className="text-[#d9fb06] font-semibold mb-4">What I'm Open To</h4>
              <ul className="space-y-3">
                {openForOptions.map((option, idx) => (
                  <li key={idx} className="flex items-start gap-3">
                    <CheckCircle className="text-[#d9fb06] flex-shrink-0 mt-0.5" size={16} />
                    <span className="text-[#888680] text-sm leading-relaxed">{option}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>

          {/* Contact Form */}
          <div className="p-8 bg-[#1a1c1b] border border-[#3f4816]/50 rounded-2xl">
            <h3 className="text-xl font-bold text-[#f5f5f4] mb-6">Send a Message</h3>
            
            {isSubmitted ? (
              <div className="flex flex-col items-center justify-center py-12 text-center">
                <CheckCircle className="text-[#d9fb06] mb-4" size={48} />
                <h4 className="text-xl font-bold text-[#f5f5f4] mb-2">Message Sent!</h4>
                <p className="text-[#888680]">I'll get back to you soon.</p>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-5">
                <div>
                  <label className="block text-[#888680] text-sm font-medium mb-2">Name</label>
                  <input
                    type="text"
                    name="name"
                    value={formData.name}
                    onChange={handleChange}
                    required
                    className="w-full px-4 py-3 bg-[#302f2c] border border-[#3f4816]/50 rounded-xl text-[#f5f5f4] placeholder-[#888680]/50 focus:outline-none focus:border-[#d9fb06]/50 transition-colors"
                    placeholder="Your name"
                  />
                </div>

                <div>
                  <label className="block text-[#888680] text-sm font-medium mb-2">Email</label>
                  <input
                    type="email"
                    name="email"
                    value={formData.email}
                    onChange={handleChange}
                    required
                    className="w-full px-4 py-3 bg-[#302f2c] border border-[#3f4816]/50 rounded-xl text-[#f5f5f4] placeholder-[#888680]/50 focus:outline-none focus:border-[#d9fb06]/50 transition-colors"
                    placeholder="your@email.com"
                  />
                </div>

                <div>
                  <label className="block text-[#888680] text-sm font-medium mb-2">Subject</label>
                  <input
                    type="text"
                    name="subject"
                    value={formData.subject}
                    onChange={handleChange}
                    required
                    className="w-full px-4 py-3 bg-[#302f2c] border border-[#3f4816]/50 rounded-xl text-[#f5f5f4] placeholder-[#888680]/50 focus:outline-none focus:border-[#d9fb06]/50 transition-colors"
                    placeholder="What's this about?"
                  />
                </div>

                <div>
                  <label className="block text-[#888680] text-sm font-medium mb-2">Message</label>
                  <textarea
                    name="message"
                    value={formData.message}
                    onChange={handleChange}
                    required
                    rows={5}
                    className="w-full px-4 py-3 bg-[#302f2c] border border-[#3f4816]/50 rounded-xl text-[#f5f5f4] placeholder-[#888680]/50 focus:outline-none focus:border-[#d9fb06]/50 transition-colors resize-none"
                    placeholder="Tell me about your project or opportunity..."
                  />
                </div>

                <button
                  type="submit"
                  className="w-full flex items-center justify-center gap-2 bg-[#d9fb06] text-[#1a1c1b] px-8 py-4 rounded-full font-semibold hover:opacity-90 transition-all duration-200 hover:scale-[1.02]"
                >
                  <Send size={18} />
                  Send Message
                </button>
              </form>
            )}
          </div>
        </div>
      </div>
    </section>
  );
};

export default Contact;
