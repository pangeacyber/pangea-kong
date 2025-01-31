FROM kong
USER root
RUN apt-get update && apt-get install -y python3 python3-pip musl-dev libffi-dev gcc g++ file make && \
   pip3 install kong-pdk pangea-sdk==5.5.0b2 --break-system-packages
COPY pangea-kong/kong/plugins/pangea-kong /py-plugins/pangea_kong
COPY pangea_kong_config.json /py-plugins/pangea_kong
RUN chmod a+x /py-plugins/pangea_kong/handler.py
USER kong
ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 8000 8443 8001 8444
STOPSIGNAL SIGQUIT
HEALTHCHECK --interval=10s --timeout=10s --retries=10 CMD kong health
ENV PYTHONPATH=/usr/local/lib/python3.12/dist-packages
ENV KONG_DATABASE=off
# edge
# ENV PANGEA_AI_GUARD_TOKEN=pts_gkv7fmshvfukjpx3uwetdvwca4dothnr
# lve
# ENV PANGEA_AI_GUARD_TOKEN=pts_xoywsjhakwnkrju2q3rvs3rzqvkjeh37
# dev
ENV PANGEA_AI_GUARD_TOKEN=pts_gkv7fmshvfukjpx3uwetdvwca4dothnr
ENV KONG_NGINX_MAIN_ENV="PANGEA_AI_GUARD_TOKEN;env PYTHONPATH"

ENV KONG_PLUGINS=bundled,pangea_kong
ENV KONG_PLUGINSERVER_NAMES=pangea_kong
ENV KONG_PLUGINSERVER_PANGEA_KONG_SOCKET=/usr/local/kong/pangea_kong.sock
ENV KONG_PLUGINSERVER_PANGEA_KONG_START_CMD="/py-plugins/pangea_kong/handler.py -v"
ENV KONG_PLUGINSERVER_PANGEA_KONG_QUERY_CMD="/py-plugins/pangea_kong/handler.py --dump"
ENV KONG_LOG_LEVEL=info
ENV KONG_DECLARATIVE_CONFIG_STRING='{"_format_version":"1.1","services":[{"name":"test_service","host":"host.docker.internal","port":8080,"protocol":"http","routes":[{"paths":["/"]}],"plugins":[{"name":"pangea_kong"}]}]}'


CMD ["kong", "docker-start"]

