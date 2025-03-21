FROM kong
USER root
RUN apt-get update && apt-get install -y python3 python3-pip musl-dev libffi-dev gcc g++ file make && \
   pip3 install kong-pdk pangea-sdk==5.5.0b4 pangea-llm-translator==1.0.2 --break-system-packages 
COPY handler.py /py-plugins/pangea_kong/
RUN chmod a+x /py-plugins/pangea_kong/handler.py
USER kong
ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 8000 8443 8001 8444
STOPSIGNAL SIGQUIT
HEALTHCHECK --interval=10s --timeout=10s --retries=10 CMD kong health
ENV PYTHONPATH=/usr/local/lib/python3.12/dist-packages
ENV KONG_NGINX_MAIN_ENV="PYTHONPATH; env PANGEA_AI_GUARD_TOKEN; env PANGEA_AI_GUARD_TOKEN_SECRET; env PANGEA_KONG_CONFIG_FILE"

ENV KONG_PLUGINS=bundled,pangea_kong
ENV KONG_PLUGINSERVER_NAMES=pangea_kong
ENV KONG_PLUGINSERVER_PANGEA_KONG_SOCKET=/usr/local/kong/pangea_kong.sock
ENV KONG_PLUGINSERVER_PANGEA_KONG_START_CMD="/py-plugins/pangea_kong/handler.py -v"
ENV KONG_PLUGINSERVER_PANGEA_KONG_QUERY_CMD="/py-plugins/pangea_kong/handler.py --dump"
ENV KONG_LOG_LEVEL=info

CMD ["kong", "docker-start"]
